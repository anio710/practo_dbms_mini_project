DELIMITER $$

CREATE TRIGGER trg_insert_payment_after_order
AFTER INSERT ON PHARMACY_ORDER
FOR EACH ROW
BEGIN
  DECLARE total_cost DECIMAL(10,2);

  -- Calculate total cost from medicines in the linked prescription
  SELECT 
    IFNULL(SUM(m.price *
               (CAST(REGEXP_SUBSTR(pm.frequency, '[0-9]+') AS UNSIGNED)) *
               (CAST(REGEXP_SUBSTR(pm.duration, '[0-9]+') AS UNSIGNED))
              ), 0)
  INTO total_cost
  FROM PRESCRIPTION_MEDICINE pm
  JOIN MEDICINE m ON pm.medicine_id = m.medicine_id
  WHERE pm.prescription_id = NEW.prescription_id;

  -- Insert corresponding payment record automatically
  INSERT INTO PAYMENT (amount, method, date, status, order_id)
  VALUES (total_cost, 'Cash', CURDATE(), 'Pending', NEW.order_id);
END$$

DELIMITER ;
