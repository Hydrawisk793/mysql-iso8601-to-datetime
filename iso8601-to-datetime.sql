
-- ----------------------------------------------------------------
-- @brief Converts an ISO 8601 string to a MySQL DATETIME value.
-- @param iso8601_value an ISO 8601 string.
-- @return an DATETIME value without offset.
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
-- SELECT iso8601_to_datetime('2022-02-20'); -> '2022-02-20 00:00:00'
-- SELECT iso8601_to_datetime('15:35:30'); -> '1000-01-01 15:35:30'
-- SELECT iso8601_to_datetime('15:35:30+09:30'); -> '1000-01-01 06:05:30'
-- SELECT iso8601_to_datetime('15:35:30-09:30'); -> '1000-01-02 01:05:30'
-- }
-- </pre>

DROP FUNCTION IF EXISTS iso8601_to_datetime;
DELIMITER $$
CREATE FUNCTION iso8601_to_datetime
(
   iso8601_value TEXT
)
RETURNS DATETIME
DETERMINISTIC
BEGIN
    DECLARE date_time_delimiter_pos INTEGER;
    DECLARE has_timezone_offset TINYINT;
    DECLARE timezone_offset_sign INTEGER;
    DECLARE timezone_offset_pos INTEGER;
    DECLARE timezone_offset_str TEXT;
    DECLARE timezone_offset_hour INTEGER;
    DECLARE timezone_offset_minute INTEGER;
    DECLARE utc_datetime DATETIME;

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

    SET timezone_offset_pos = LENGTH(iso8601_value) - LENGTH(substring_index(iso8601_value, '+', -1));
    IF timezone_offset_pos > date_time_delimiter_pos
    THEN
        SET has_timezone_offset = 1;
        SET timezone_offset_sign = -1;
    ELSE
        SET timezone_offset_pos = LENGTH(iso8601_value) - LENGTH(substring_index(iso8601_value, '-', -1));
        IF timezone_offset_pos > date_time_delimiter_pos
        THEN
            SET has_timezone_offset = 1;
            SET timezone_offset_sign = 1;
        ELSE
            SET timezone_offset_pos = POSITION('Z' IN iso8601_value);
            IF timezone_offset_pos < date_time_delimiter_pos
            THEN
                SET timezone_offset_pos = LENGTH(iso8601_value) + 1;
            END IF;

            SET has_timezone_offset = 0;
            SET timezone_offset_sign = 0;
        END IF;
    END IF;

    IF has_timezone_offset > 0
    THEN
        SET timezone_offset_str = SUBSTRING(iso8601_value, timezone_offset_pos + 1);

        IF POSITION(':' IN timezone_offset_str) > 0
        THEN
            SET timezone_offset_hour = timezone_offset_sign * HOUR(timezone_offset_str);
            SET timezone_offset_minute = timezone_offset_sign * MINUTE(timezone_offset_str);
        ELSEIF LENGTH(timezone_offset_str) > 2
        THEN
            SET timezone_offset_hour = timezone_offset_sign * HOUR(STR_TO_DATE(timezone_offset_str, '%H%i'));
            SET timezone_offset_minute = timezone_offset_sign * MINUTE(STR_TO_DATE(timezone_offset_str, '%H%i'));
        ELSE
            SET timezone_offset_hour = timezone_offset_sign * HOUR(STR_TO_DATE(timezone_offset_str, '%H'));
            SET timezone_offset_minute = 0;
        END IF;
    ELSE
        SET timezone_offset_hour = 0;
        SET timezone_offset_minute = 0;
    END IF;

    SET utc_datetime = STR_TO_DATE(SUBSTR(iso8601_value, 1, timezone_offset_pos - 1), '%Y-%m-%dT%H:%i:%s');
    SET utc_datetime = DATE_ADD(utc_datetime, INTERVAL timezone_offset_hour HOUR);
    SET utc_datetime = DATE_ADD(utc_datetime, INTERVAL timezone_offset_minute MINUTE);

    RETURN utc_datetime;
END;
$$
DELIMITER ;

-- ----------------------------------------------------------------
