DROP PROCEDURE IF EXISTS `init_risk_path`;
DELIMITER ;;
CREATE PROCEDURE `init_risk_path`(WSCODE VARCHAR(10))
BEGIN
	DECLARE ORGANID VARCHAR (32);
	DECLARE TMPID VARCHAR (32);
	DECLARE TMPPATH LONGTEXT;
	DECLARE DONE INT DEFAULT 0;
	DECLARE CT INT;
	DECLARE CUR_ORG CURSOR FOR SELECT RISK_ID FROM WWYT_FACTOR_RISK WHERE WS_CODE = WSCODE AND RISK_ID <> PARENT_RISK order by RISK_CODE;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET DONE = 1;

	OPEN CUR_ORG; 
		REPEAT
			FETCH CUR_ORG INTO ORGANID;
			SET TMPPATH = '';
			SET TMPID = ORGANID;
			WHILE (TMPID IS NOT NULL) DO
					IF TMPPATH = '' THEN
						SET TMPPATH = TMPID;
					ELSE
						SET TMPPATH = CONCAT(TMPID, "/",TMPPATH);
					END IF;
					SELECT COUNT(1) INTO CT FROM WWYT_FACTOR_RISK WHERE WS_CODE = WSCODE AND RISK_ID = TMPID and RISK_ID <> PARENT_RISK;
					IF CT > 0 THEN
						SELECT DISTINCT O.PARENT_RISK INTO TMPID FROM WWYT_FACTOR_RISK O WHERE WS_CODE = WSCODE AND RISK_ID <> PARENT_RISK AND RISK_ID = TMPID LIMIT 1;
					ELSE
						SET TMPID = NULL;
					END IF;
			END WHILE;
			UPDATE WWYT_FACTOR_RISK O SET O.RISK_PATH = TMPPATH WHERE WS_CODE = WSCODE AND  O.RISK_ID = ORGANID and  RISK_ID <> PARENT_RISK ;
		UNTIL DONE = 1 END REPEAT;
	CLOSE CUR_ORG;



		UPDATE WWYT_FACTOR_RISK d
			LEFT JOIN ( SELECT DISTINCT parent_risk, WS_CODE FROM WWYT_FACTOR_RISK ) p
				ON d.risk_code = p.parent_risk AND ( d.WS_CODE = p.WS_CODE OR p.parent_risk = 'SGCC-ROOT' )
		  SET d.has_child = ( CASE WHEN p.parent_risk IS NULL THEN '0' ELSE '1' END )
where d.WS_CODE =  WSCODE  ;
		commit;
	COMMIT;
END
;;
DELIMITER ;


DROP PROCEDURE IF EXISTS `proc_refresh_factor_source`;
DELIMITER ;;
CREATE PROCEDURE `proc_refresh_factor_source`(IN `FACTOR_TYPE` varchar(10),IN `V_WS_CODE` varchar(20))
BEGIN
	# 1.将引用总部要素的数据来源设置为T
	# 2.将省公司自己的要素数据来源设置为W
	#制度
	IF FACTOR_TYPE = '51' THEN
		update wwyt_factor_rule t, wwyt_factor_rule tt
		set t.factor_source = 'T'
		where tt.ID = t.ID AND tt.WS_CODE = '99' AND t.WS_CODE = V_WS_CODE;

		update wwyt_factor_rule r SET r.FACTOR_SOURCE = 'W' WHERE r.WS_CODE = '99';
		
		update wwyt_factor_rule r SET r.FACTOR_SOURCE = 'W' WHERE r.FACTOR_SOURCE IS NULL AND r.WS_CODE = V_WS_CODE;
	#标准
	ELSEIF FACTOR_TYPE = '52' THEN
		update wwyt_factor_standard t, wwyt_factor_standard tt
		set t.factor_source = 'T'
		where tt.STANDARD_ID = t.STANDARD_ID AND tt.WS_CODE = '99' AND t.WS_CODE = V_WS_CODE;

		update wwyt_factor_standard r SET r.FACTOR_SOURCE = 'W' WHERE r.WS_CODE = '99';

		update wwyt_factor_standard r SET r.FACTOR_SOURCE = 'W' WHERE r.FACTOR_SOURCE IS NULL AND r.WS_CODE = V_WS_CODE;
	#绩效
	ELSEIF FACTOR_TYPE = '53' THEN
		update wwyt_factor_per_indicator t, wwyt_factor_per_indicator tt
		set t.factor_source = 'T'
		where tt.INDICATOR_ID = t.INDICATOR_ID AND tt.WS_CODE = '99' AND t.WS_CODE = V_WS_CODE;

		update wwyt_factor_per_indicator r SET r.FACTOR_SOURCE = 'W' WHERE r.WS_CODE = '99';

		update wwyt_factor_per_indicator r SET r.FACTOR_SOURCE = 'W' WHERE r.FACTOR_SOURCE IS NULL AND r.WS_CODE = V_WS_CODE;
	#风控
	ELSEIF FACTOR_TYPE = '54' THEN
		
		update wwyt_factor_risk t, wwyt_factor_risk tt
		set t.factor_source = 'T'
		where tt.RISK_ID = t.RISK_ID AND tt.WS_CODE = '99' AND t.WS_CODE = V_WS_CODE;

		update wwyt_factor_risk r SET r.FACTOR_SOURCE = 'W' WHERE r.WS_CODE = '99';
		
		update wwyt_factor_risk r SET r.FACTOR_SOURCE = 'W' WHERE r.FACTOR_SOURCE IS NULL AND r.WS_CODE = V_WS_CODE;

		# 控制随风险要素来源
		update wwyt_factor_control c
		INNER JOIN wwyt_factor_risk_control_ref cr on c.CONTROL_ID = cr.CONTROL_ID AND c.WS_CODE = cr.WS_CODE
		INNER JOIN wwyt_factor_risk r ON cr.RISK_ID = r.RISK_ID AND cr.WS_CODE = r.WS_CODE
		SET c.FACTOR_SOURCE = r.FACTOR_SOURCE
		where r.WS_CODE = V_WS_CODE;

		update wwyt_factor_control r SET r.FACTOR_SOURCE = 'W' WHERE r.WS_CODE = '99';
	
	END IF;
END
;;
DELIMITER ;

DROP PROCEDURE IF EXISTS `proc_delete_aris_redundancy_data`;
DELIMITER ;;
CREATE PROCEDURE `proc_delete_aris_redundancy_data`(IN `V_WS_CODE` varchar(20), IN `V_TYPE` varchar(20))
BEGIN
	# 1.根据flow_picId、ws_code删除冗余数据
	IF V_TYPE = 'flow' THEN
		
		DELETE f FROM wwyt_flow_factor_relation f WHERE f.WS_CODE = V_WS_CODE AND NOT EXISTS(
			select * from (
				select p.FLOW_PICID from wwyt_flow_pic p where p.ws_code = V_WS_CODE
				UNION
				select p.FLOW_PICID from wwyt_flow_work p where p.ws_code = V_WS_CODE
				UNION
				select p.FLOW_PICID from wwyt_flow_face2face p where p.ws_code = V_WS_CODE
			) t where t.flow_picid = f.FLOW_PICID
		);
		
	ELSEIF V_TYPE = 'flowNode' THEN
		DELETE f FROM wwyt_flow_json f WHERE f.WS_CODE = V_WS_CODE AND NOT EXISTS(
			select * from (
				select p.FLOW_PICID from wwyt_flow_pic p where p.ws_code = V_WS_CODE
				UNION
				select p.FLOW_PICID from wwyt_flow_work p where p.ws_code = V_WS_CODE
				UNION
				select p.FLOW_PICID from wwyt_flow_face2face p where p.ws_code = V_WS_CODE
			) t where t.flow_picid = f.FLOW_PICID
		); 


		DELETE f FROM wwyt_flow_node f WHERE f.WS_CODE = V_WS_CODE AND NOT EXISTS(
			select * from (
				select p.FLOW_PICID from wwyt_flow_pic p where p.ws_code = V_WS_CODE
				UNION
				select p.FLOW_PICID from wwyt_flow_work p where p.ws_code = V_WS_CODE
				UNION
				select p.FLOW_PICID from wwyt_flow_face2face p where p.ws_code = V_WS_CODE
			) t where t.flow_picid = f.FLOW_PICID
		);

		DELETE f FROM wwyt_flow_node_factor_relation f WHERE f.WS_CODE = V_WS_CODE AND NOT EXISTS(
			select * from (
				select p.FLOW_PICID from wwyt_flow_pic p where p.ws_code = V_WS_CODE
				UNION
				select p.FLOW_PICID from wwyt_flow_work p where p.ws_code = V_WS_CODE
				UNION
				select p.FLOW_PICID from wwyt_flow_face2face p where p.ws_code = V_WS_CODE
			) t where t.flow_picid = f.FLOW_PICID
		);
		
	
	END IF;
END
;;
DELIMITER ;

DROP PROCEDURE IF EXISTS `proc_aris_data_refresh_factor`;
DELIMITER ;;
CREATE PROCEDURE `proc_aris_data_refresh_factor`(IN `V_TYPE` varchar(20),IN `V_WS_CODE` varchar(20))
BEGIN
	# 各网省复制顶层数据
	#1.制度
	IF V_TYPE = '51' THEN
		IF V_WS_CODE<>'99' THEN
			INSERT INTO WWYT_FACTOR_RULE 
					(ID, WS_CODE, RULE_CODE,PARENT_ID, ORG_ID, RULE_NAME, RULE_TYPE, RULE_LEVEL,RULE_STATE, MAJOR_TYPE, INIT_DEPT_ID, 
					INIT_DEPT_NAME, RELEASE_DATE, EXCUTE_DATE, FILE_NO, FILE_NAME, FILE_ATTACHMENTS, REMARK,FACTOR_SOURCE)
				SELECT ID, V_WS_CODE AS WS_CODE, RULE_CODE,PARENT_ID, ORG_ID, RULE_NAME, RULE_TYPE, RULE_LEVEL,RULE_STATE, MAJOR_TYPE, INIT_DEPT_ID,INIT_DEPT_NAME, RELEASE_DATE, EXCUTE_DATE, FILE_NO, FILE_NAME, FILE_ATTACHMENTS, REMARK,'T' 
					FROM wwyt_factor_rule WHERE WS_CODE='99' AND ID NOT IN(SELECT ID FROM wwyt_factor_rule WHERE WS_CODE=V_WS_CODE);
			
			INSERT INTO WWYT_FACTOR_RULE_ITEM 
					(ITEM_ID, WS_CODE, RULE_ID, ITEM_CODE, PARENT_ID, ITEM_CONTENT, ITEM_TYPE, ORDER_NO, REMARK,FACTOR_SOURCE)
				SELECT ITEM_ID, V_WS_CODE AS WS_CODE, RULE_ID, ITEM_CODE, PARENT_ID, ITEM_CONTENT, ITEM_TYPE, ORDER_NO, REMARK,'T'
					FROM WWYT_FACTOR_RULE_ITEM WHERE WS_CODE='99' AND ITEM_ID NOT IN(SELECT ITEM_ID FROM WWYT_FACTOR_RULE_ITEM WHERE WS_CODE=V_WS_CODE);
		END IF;
	#2.标准
	ELSEIF V_TYPE = '52' THEN
		IF V_WS_CODE<>'99' THEN
			INSERT INTO wwyt_factor_standard
				(STANDARD_ID, WS_CODE, STANDARD_NO, STANDARD_PART_TYPE, STARDARD_NAME,ORG_ID, DOCUMENT_CODE,STARDARD_SUMMARY, 
				STANDARD_TYPE, RECORD_STATE, EXCUTE_DATE, RELEASE_DATE, ABOLISH_DATE, DEPT_ID,REMARK,FACTOR_SOURCE)
			SELECT STANDARD_ID, V_WS_CODE AS WS_CODE, STANDARD_NO, STANDARD_PART_TYPE, STARDARD_NAME,ORG_ID, DOCUMENT_CODE,STARDARD_SUMMARY,STANDARD_TYPE, RECORD_STATE, EXCUTE_DATE, RELEASE_DATE, ABOLISH_DATE, DEPT_ID,REMARK,'T'
				FROM wwyt_factor_standard WHERE WS_CODE='99' AND STANDARD_ID NOT IN(SELECT STANDARD_ID FROM wwyt_factor_standard WHERE WS_CODE=V_WS_CODE);
		END IF;
	#3.绩效
	ELSEIF V_TYPE = '53' THEN
		IF V_WS_CODE<>'99' THEN
			INSERT INTO WWYT_FACTOR_PER_INDICATOR 
				(INDICATOR_ID, WS_CODE, INDICATOR_CODE, INDICATOR_NAME, INDICATOR_PART_TYPE, ORG_ID, MEASUREMENT_UNIT, INDICATOR_DEFINE,EVALUATE_STANDARD, 
				EXAMINE_DEPT_ID, INDICATOR_SOURCE, DEPT_ID, POST_ID, FIRST_MENU, SECOND_MENU, THIRD_MENU, FOURTH_MENU, EXAMINER_ROUND, DATA_SOURCE, REMARK,FACTOR_SOURCE) 
			SELECT INDICATOR_ID, V_WS_CODE AS WS_CODE, INDICATOR_CODE, INDICATOR_NAME, INDICATOR_PART_TYPE, ORG_ID, MEASUREMENT_UNIT, INDICATOR_DEFINE,EVALUATE_STANDARD,EXAMINE_DEPT_ID, INDICATOR_SOURCE, DEPT_ID, POST_ID, FIRST_MENU, SECOND_MENU, THIRD_MENU, FOURTH_MENU, EXAMINER_ROUND, DATA_SOURCE, REMARK,'T'
				FROM WWYT_FACTOR_PER_INDICATOR WHERE WS_CODE='99' AND INDICATOR_ID NOT IN(SELECT INDICATOR_ID FROM WWYT_FACTOR_PER_INDICATOR WHERE WS_CODE=V_WS_CODE);
		END IF;
	#4.风控
	ELSEIF V_TYPE = '54' THEN
		IF V_WS_CODE<>'99' THEN
			#风险
			INSERT INTO WWYT_FACTOR_RISK 
				(RISK_ID,WS_CODE,RISK_CODE,RISK_NAME,RISK_LEVEL,RISK_DEPT_ID,RISK_DEPT_NAME,PARENT_RISK,RISK_DEFINE,RISK_TYPE,RISK_CAUSE,EASY_HAPPEN_LINK,EASY_HAPPEN_POST,	
					PREVENT_MEASURES,RULE_ACCORDING,PREVENT_ORG,MONITOR_INDICATOR,IF_FLOW,IS_FINAL,RISK_PATH,HAS_CHILD,FACTOR_SOURCE)	
			SELECT RISK_ID,V_WS_CODE AS WS_CODE,RISK_CODE,RISK_NAME,RISK_LEVEL,RISK_DEPT_ID,RISK_DEPT_NAME,PARENT_RISK,RISK_DEFINE,RISK_TYPE,RISK_CAUSE,EASY_HAPPEN_LINK,EASY_HAPPEN_POST,PREVENT_MEASURES,RULE_ACCORDING,PREVENT_ORG,MONITOR_INDICATOR,IF_FLOW,IS_FINAL,RISK_PATH,HAS_CHILD,'T'	
				FROM WWYT_FACTOR_RISK WHERE WS_CODE='99' AND RISK_LEVEL>3 AND RISK_ID NOT IN(SELECT RISK_ID FROM WWYT_FACTOR_RISK WHERE WS_CODE=V_WS_CODE);
			#控制
			INSERT INTO WWYT_FACTOR_CONTROL 
				(CONTROL_ID, WS_CODE, CONTROL_CODE, CONTROL_NAME, CONTROL_DESCRIBE,CONTROL_CONTENT, IS_KEY, CONTROL_PATTERN, STAR_DATE, BEGIN_DATE, END_DATE, REMARK, FINAL_RISK_CODE ,FACTOR_SOURCE)
			SELECT CONTROL_ID, V_WS_CODE AS WS_CODE, CONTROL_CODE, CONTROL_NAME, CONTROL_DESCRIBE,CONTROL_CONTENT, IS_KEY, CONTROL_PATTERN, STAR_DATE, BEGIN_DATE, END_DATE, REMARK, FINAL_RISK_CODE ,'T'
				FROM WWYT_FACTOR_CONTROL WHERE WS_CODE='99' AND CONTROL_ID NOT IN(SELECT CONTROL_ID FROM WWYT_FACTOR_CONTROL WHERE WS_CODE=V_WS_CODE);
			#风控的关系
			INSERT INTO wwyt_factor_risk_control_ref
				(RISK_ID,CONTROL_ID,WS_CODE)
			SELECT RISK_ID,CONTROL_ID,V_WS_CODE AS WS_CODE
				FROM wwyt_factor_risk_control_ref WHERE WS_CODE='99';

		END IF;

	END IF;

END
;;
DELIMITER ;

DROP PROCEDURE IF EXISTS `proc_aris_data_refresh_all`;
DELIMITER ;;
CREATE PROCEDURE `proc_aris_data_refresh_all`(IN `V_FLOW_PICID` varchar(32),IN `V_WS_CODE` varchar(20))
BEGIN
	# 各网省复制顶层数据
	# 1.流程关系表
	INSERT INTO wwyt_flow_factor_relation(FLOW_PICID, FACTOR_ID, FACTOR_TYPE, REMARK, WS_CODE)
	SELECT r.FLOW_PICID, r.FACTOR_ID, r.FACTOR_TYPE, r.REMARK, V_WS_CODE WS_CODE from wwyt_flow_factor_relation r
	WHERE r.WS_CODE= '99' AND r.FLOW_PICID=V_FLOW_PICID;

	# 2.流程节点表
	INSERT INTO wwyt_flow_node(NODE_ID, node_no, flow_picid, flow_version, node_type, node_name, NODE_DESC, NEXT_NODE, NEXT_NODE_NAME, NEXT_NODE_DESC, WS_CODE)
	select r.NODE_ID, r.node_no, flow_picid, r.flow_version, r.node_type, r.node_name, r.NODE_DESC, r.NEXT_NODE, r.NEXT_NODE_NAME, r.NEXT_NODE_DESC, V_WS_CODE WS_CODE from wwyt_flow_node r
	WHERE r.WS_CODE= '99' AND r.FLOW_PICID=V_FLOW_PICID;
		

	# 3.流程节点关系表
	INSERT INTO wwyt_flow_node_factor_relation(PRO_ID, FACTOR_ID, FACTOR_TYPE, UNIT_ID, REMARK, FLOW_PICID, WS_CODE)
	select r.PRO_ID, r.FACTOR_ID, r.FACTOR_TYPE, r.UNIT_ID, r.REMARK, r.FLOW_PICID, V_WS_CODE WS_CODE from wwyt_flow_node_factor_relation r
	WHERE r.WS_CODE= '99' AND r.FLOW_PICID=V_FLOW_PICID;
	
	# 4.流程JSON表
	INSERT INTO wwyt_flow_json(FLOW_PICID, WS_CODE, JSON_DATA, FLOW_NOTE)
	select r.FLOW_PICID, V_WS_CODE WS_CODE, r.JSON_DATA, r.FLOW_NOTE from wwyt_flow_json r
	WHERE r.WS_CODE= '99' AND r.FLOW_PICID=V_FLOW_PICID;

END
;;
DELIMITER ;

DROP PROCEDURE IF EXISTS `proc_aris_data_refresh`;
DELIMITER ;;
CREATE PROCEDURE `proc_aris_data_refresh`(IN `V_WS_CODE` varchar(20),IN `V_TYPE` varchar(20))
BEGIN
	# 各网省复制顶层数据
	IF V_WS_CODE<>'99' THEN
		IF V_TYPE = 'flow' THEN
			# 1.流程关系表
			INSERT INTO wwyt_flow_factor_relation(FLOW_PICID, FACTOR_ID, FACTOR_TYPE, REMARK, WS_CODE)
			SELECT r.FLOW_PICID, r.FACTOR_ID, r.FACTOR_TYPE, r.REMARK, V_WS_CODE WS_CODE from wwyt_flow_factor_relation r
			WHERE r.WS_CODE= '99' AND NOT EXISTS (
				SELECT r1.flow_picid, r1.FACTOR_ID FROM wwyt_flow_factor_relation r1 
				INNER JOIN wwyt_flow_factor_relation r2 ON r1.FLOW_PICID = r2.FLOW_PICID AND r1.FACTOR_ID = r2.FACTOR_ID AND r2.WS_CODE = V_WS_CODE
				WHERE r1.WS_CODE = r.WS_CODE AND r.FACTOR_ID = r1.FACTOR_ID and r.FLOW_PICID = r1.flow_picid
			);

		ELSEIF V_TYPE = 'flowNode' THEN
			# 2.流程节点表
			INSERT INTO wwyt_flow_node(NODE_ID, node_no, flow_picid, flow_version, node_type, node_name, NODE_DESC, NEXT_NODE, NEXT_NODE_NAME, NEXT_NODE_DESC, WS_CODE)
			select r.NODE_ID, r.node_no, flow_picid, r.flow_version, r.node_type, r.node_name, r.NODE_DESC, r.NEXT_NODE, r.NEXT_NODE_NAME, r.NEXT_NODE_DESC, V_WS_CODE WS_CODE from wwyt_flow_node r
			WHERE r.WS_CODE= '99' AND NOT EXISTS (
				SELECT r1.NODE_ID, r1.FLOW_PICID FROM wwyt_flow_node r1 
				INNER JOIN wwyt_flow_node r2 ON r1.NODE_ID = r2.NODE_ID AND r1.FLOW_PICID = r2.FLOW_PICID AND r2.WS_CODE = V_WS_CODE
				WHERE r1.WS_CODE = r.WS_CODE AND r.NODE_ID = r1.NODE_ID and r.FLOW_PICID = r1.flow_picid
			);

			# 3.流程节点关系表
			INSERT INTO wwyt_flow_node_factor_relation(PRO_ID, FACTOR_ID, FACTOR_TYPE, UNIT_ID, REMARK, FLOW_PICID, WS_CODE)
			select r.PRO_ID, r.FACTOR_ID, r.FACTOR_TYPE, r.UNIT_ID, r.REMARK, r.FLOW_PICID, V_WS_CODE WS_CODE from wwyt_flow_node_factor_relation r
			WHERE r.WS_CODE= '99' AND NOT EXISTS (
				SELECT r1.pro_id, r1.factor_id, r1.FLOW_PICID FROM wwyt_flow_node_factor_relation r1 
				INNER JOIN wwyt_flow_node_factor_relation r2 ON r1.FLOW_PICID = r2.FLOW_PICID AND r1.PRO_ID = r2.PRO_ID AND r1.FACTOR_ID = r2.FACTOR_ID AND r2.WS_CODE = V_WS_CODE
				WHERE r1.WS_CODE = r.WS_CODE AND r.FLOW_PICID = r1.FLOW_PICID and r.PRO_ID = r1.PRO_ID and r.FACTOR_ID = r1.FACTOR_ID
			);
			
			# 4.流程JSON表
			INSERT INTO wwyt_flow_json(FLOW_PICID, WS_CODE, JSON_DATA, FLOW_NOTE)
			select r.FLOW_PICID, V_WS_CODE WS_CODE, r.JSON_DATA, r.FLOW_NOTE from wwyt_flow_json r
			WHERE r.WS_CODE= '99' AND NOT EXISTS (
				SELECT r1.FLOW_PICID, r1.WS_CODE FROM wwyt_flow_json r1 
				INNER JOIN wwyt_flow_json r2 ON r1.FLOW_PICID = r2.FLOW_PICID AND r2.WS_CODE = V_WS_CODE
				WHERE r1.WS_CODE = r.WS_CODE AND r.FLOW_PICID = r1.FLOW_PICID
			);

		END IF;
	END IF;
END
;;
DELIMITER ;


DROP PROCEDURE IF EXISTS `p_init_flow_work_ref`;
DELIMITER ;;
CREATE PROCEDURE `p_init_flow_work_ref`(WSCODE VARCHAR(10))
BEGIN 

		#先清除旧数据
		DELETE FROM wwyt_flow_pic_work_ref WHERE ws_code=WSCODE;
		#插入流程与标准作业程序的关系
		INSERT INTO wwyt_flow_pic_work_ref 
		SELECT REPLACE(UUID(),'-',''),f.FLOW_PICID,f.FLOW_NAME,w.FLOW_PICID,w.FLOW_NAME,f.WS_CODE,NULL FROM wwyt_flow_pic f
			LEFT JOIN wwyt_flow_node n ON f.FLOW_PICID=n.FLOW_PICID AND f.WS_CODE=n.WS_CODE
			LEFT JOIN wwyt_flow_node_factor_relation nr ON nr.PRO_ID=n.NODE_ID AND nr.FACTOR_TYPE='process_role' AND nr.WS_CODE=n.WS_CODE
			INNER JOIN wwyt_factor_role_mapping_factor rf ON rf.ROLE_ID=nr.FACTOR_ID AND rf.FACTOR_TYPE=2 AND rf.WS_CODE=nr.WS_CODE
			INNER JOIN wwyt_flow_work w ON w.FLOW_ID=rf.FACTOR_ID AND w.WS_CODE=rf.WS_CODE
		WHERE f.WS_CODE=WSCODE; 

		#先删除旧数据
		DELETE  FROM WWYT_FLOW_NODE_FACTOR_RELATION  WHERE WS_CODE=WSCODE AND FACTOR_TYPE='process_post';
		#再插入新数据
		INSERT INTO WWYT_FLOW_NODE_FACTOR_RELATION(PRO_ID,FACTOR_ID,FACTOR_TYPE,FLOW_PICID,WS_CODE)
		SELECT rn.PRO_ID, rm.FACTOR_ID,'process_post',rn.FLOW_PICID,rm.WS_CODE 
		FROM wwyt_factor_role_mapping_factor rm
		INNER JOIN WWYT_FLOW_NODE_FACTOR_RELATION rn ON rn.FACTOR_ID=rm.ROLE_ID AND rn.FACTOR_TYPE='process_role' AND rn.WS_CODE=rm.WS_CODE
		WHERE rm.WS_CODE=WSCODE AND rm.FACTOR_TYPE=1;
	
    COMMIT;  
END
;;
DELIMITER ;