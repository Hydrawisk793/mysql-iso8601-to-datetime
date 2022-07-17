-- ----------------------------------------------------------------
-- @brief Converts an ISO 8601 string to a MySQL DATETIME(6) value.
-- @param iso8601_value an ISO 8601 string.
-- @return an DATETIME(6) value without offset.
-- <pre>
-- {@code
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30+09:00'); -> '2022-02-20 06:35:30'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30-09:00'); -> '2022-02-21 00:35:30'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30+09'); -> '2022-02-20 06:35:30'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30-09'); -> '2022-02-21 00:35:30'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30+09:30'); -> '2022-02-20 06:05:30'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30-09:30'); -> '2022-02-21 01:05:30'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30+0930'); -> '2022-02-20 06:05:30'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30-0930'); -> '2022-02-21 01:05:30'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30Z'); -> '2022-02-20 15:35:30'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888+09:00'); -> '2022-02-20 06:35:30.888000'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888-09:00'); -> '2022-02-21 00:35:30.888000'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888+09'); -> '2022-02-20 06:35:30.888000'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888-09'); -> '2022-02-21 00:35:30.888000'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888+09:30'); -> '2022-02-20 06:05:30.888000'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888-09:30'); -> '2022-02-21 01:05:30.888000'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888+0930'); -> '2022-02-20 06:05:30.888000'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888-0930'); -> '2022-02-21 01:05:30.888000'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888Z'); -> '2022-02-20 15:35:30.888000'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888777+09:00'); -> '2022-02-20 06:35:30.888777'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888777-09:00'); -> '2022-02-21 00:35:30.888777'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888777+09'); -> '2022-02-20 06:35:30.888777'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888777-09'); -> '2022-02-21 00:35:30.888777'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888777+09:30'); -> '2022-02-20 06:05:30.888777'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888777-09:30'); -> '2022-02-21 01:05:30.888777'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888777+0930'); -> '2022-02-20 06:05:30.888777'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888777-0930'); -> '2022-02-21 01:05:30.888777'
-- SELECT iso8601_to_datetime('2022-02-20T15:35:30.888777Z'); -> '2022-02-20 15:35:30.888777'
-- SELECT iso8601_to_datetime('2022-02-20'); -> '2022-02-20 00:00:00.000000'
-- SELECT iso8601_to_datetime('15:35:30'); -> '1000-01-01 15:35:30.000000'
-- SELECT iso8601_to_datetime('15:35:30+09:30'); -> '1000-01-01 06:05:30.000000'
-- SELECT iso8601_to_datetime('15:35:30-09:30'); -> '1000-01-02 01:05:30.000000'
-- }
-- </pre>

DROP FUNCTION IF EXISTS iso8601_to_datetime;
DELIMITER $$
CREATE FUNCTION iso8601_to_datetime
(
   iso8601_value TEXT
)
RETURNS DATETIME(6)
DETERMINISTIC
BEGIN
    DECLARE date_time_delimiter_pos INTEGER;
    DECLARE has_offset TINYINT;
    DECLARE offset_sign INTEGER;
    DECLARE offset_pos INTEGER;
    DECLARE offset_str TEXT;
    DECLARE offset_hour INTEGER;
    DECLARE offset_minute INTEGER;
    DECLARE utc_datetime_str TEXT;
    DECLARE datetime_str TEXT;
    DECLARE offset_precision_pos INTEGER;
    DECLARE offset_precision_str TEXT;
    DECLARE offset_microseconds INTEGER;
    DECLARE utc_datetime DATETIME(6);

    SET date_time_delimiter_pos = POSITION('T' IN iso8601_value);
    IF date_time_delimiter_pos < 1
    THEN
        IF POSITION(':' IN iso8601_value) < 1
        THEN
            SET iso8601_value = CONCAT(iso8601_value, 'T', '00:00:00');
            SET date_time_delimiter_pos = POSITION('T' IN iso8601_value);
        ELSE
            SET iso8601_value = CONCAT('1000-01-01', 'T', iso8601_value);
            SET date_time_delimiter_pos = POSITION('T' IN iso8601_value);
        END IF;
    END IF;

    SET offset_pos = LENGTH(iso8601_value) - LENGTH(substring_index(iso8601_value, '+', -1));
    IF offset_pos > date_time_delimiter_pos
    THEN
        SET has_offset = 1;
        SET offset_sign = -1;
    ELSE
        SET offset_pos = LENGTH(iso8601_value) - LENGTH(substring_index(iso8601_value, '-', -1));
        IF offset_pos > date_time_delimiter_pos
        THEN
            SET has_offset = 1;
            SET offset_sign = 1;
        ELSE
            SET offset_pos = POSITION('Z' IN iso8601_value);
            IF offset_pos < date_time_delimiter_pos
            THEN
                SET offset_pos = LENGTH(iso8601_value) + 1;
            END IF;

            SET has_offset = 0;
            SET offset_sign = 0;
        END IF;
    END IF;

    IF has_offset > 0
    THEN
        SET offset_str = SUBSTRING(iso8601_value, offset_pos + 1);

        IF POSITION(':' IN offset_str) > 0
        THEN
            SET offset_hour = offset_sign * HOUR(offset_str);
            SET offset_minute = offset_sign * MINUTE(offset_str);
        ELSEIF LENGTH(offset_str) > 2
        THEN
            SET offset_hour = offset_sign * HOUR(STR_TO_DATE(offset_str, '%H%i'));
            SET offset_minute = offset_sign * MINUTE(STR_TO_DATE(offset_str, '%H%i'));
        ELSE
            SET offset_hour = offset_sign * HOUR(STR_TO_DATE(offset_str, '%H'));
            SET offset_minute = 0;
        END IF;
    ELSE
        SET offset_hour = 0;
        SET offset_minute = 0;
    END IF;

    SET utc_datetime_str = SUBSTR(iso8601_value, 1, offset_pos - 1);
    SET offset_precision_pos = POSITION('.' IN utc_datetime_str);
    IF offset_precision_pos < 1
    THEN
        SET offset_precision_pos = LENGTH(utc_datetime_str) + 1;
        SET offset_microseconds = 0;
    ELSE
        SET offset_precision_str = SUBSTRING(utc_datetime_str, offset_precision_pos);
        SET offset_microseconds = (
            CASE LENGTH(offset_precision_str)
            WHEN 4
            THEN
                MICROSECOND(CONCAT(offset_precision_str, '000'))
            WHEN 7
            THEN
                MICROSECOND(offset_precision_str)
            ELSE
                0
            END
        );
    END IF;

    SET utc_datetime = STR_TO_DATE(SUBSTR(utc_datetime_str, 1, offset_precision_pos - 1), '%Y-%m-%dT%H:%i:%s');
    SET utc_datetime = DATE_ADD(utc_datetime, INTERVAL offset_hour HOUR);
    SET utc_datetime = DATE_ADD(utc_datetime, INTERVAL offset_minute MINUTE);
    SET utc_datetime = DATE_ADD(utc_datetime, INTERVAL offset_microseconds MICROSECOND);

    RETURN utc_datetime;
END;
$$
DELIMITER ;

-- ----------------------------------------------------------------
