
#启动定时器
SET GLOBAL event_scheduler = 1;
#创建定时器事件
DROP EVENT IF EXISTS `delete_nopay_order`;
DELIMITER ;;
CREATE EVENT `delete_nopay_order` ON SCHEDULE EVERY 1 MINUTE STARTS '2019-06-14 09:00:00' ON COMPLETION NOT PRESERVE ENABLE DO
BEGIN
	-- 将超出10分钟未支付（1）的订单状态更新为已取消（3）
	UPDATE md1k_orders SET status=3 where `status`=1 and TIMESTAMPDIFF(MINUTE,sys_created,now())>10;
END
;;
DELIMITER ;

#开启定时任务
ALTER EVENT delete_nopay_order ON  COMPLETION PRESERVE ENABLE;
#关闭定时任务
ALTER EVENT delete_nopay_order ON  COMPLETION PRESERVE DISABLE;