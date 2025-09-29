---- Checking data types for suitability with analysis 
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'mock_trade_data'  
ORDER BY ORDINAL_POSITION;

SELECT TOP 10 *
FROM [mock_trade_data ]

--- What percentage of trades are delayed in settlement, and which factors contribute to these delays?
SELECT status
FROM [mock_trade_data ]
WHERE status = 'Delayed';

-- how many is delayed?
SELECT COUNT(status)
FROM [mock_trade_data ]
WHERE status = 'Delayed';

--What is the percentage of trade that is delayed?
SELECT 
(COUNT(CASE WHEN status = 'Delayed' THEN 1  END) * 100 / COUNT(*)) as DelayPercentage
FROM [mock_trade_data ]

--- More info on delayed trade settlements
SELECT 
COUNT (status) AS numofdelayed, COUNT(counterparty) as cpdelayed, COUNT(instrument_type) as instrtype
FROM [mock_trade_data ]
WHERE status = 'Delayed';

--Identify high risk counterparties with delayed settlements greater than 5%
SELECT counterparty,
	COUNT(*) as TotalTrades,
	SUM (CASE WHEN status = 'Delayed' THEN 1 ELSE 0 END) AS DelayedTrades,
	(SUM(CASE WHEN status = 'Delayed' THEN 1 Else 0  END) * 100 / COUNT(*)) AS DelayRate
FROM [mock_trade_data ]
GROUP BY counterparty
HAVING (SUM(CASE WHEN status = 'Delayed' THEN 1 Else 0  END) * 100 / COUNT(*)) > 5
ORDER BY DelayRate DESC, TotalTrades DESC

--Finding the problem instrument for the worst counterparty which we found to be Counterparty_3
SELECT
    instrument_type,
    COUNT(*) AS Number_of_Delays
FROM [mock_trade_data ]
WHERE counterparty = 'Counterparty_3'
  AND status = 'Delayed'
GROUP BY instrument_type
ORDER BY Number_of_Delays DESC;
--- Followed by Counterparty_7
SELECT
    instrument_type,
    COUNT(*) AS Number_of_Delays
FROM [mock_trade_data ]
WHERE counterparty = 'Counterparty_7'
  AND status = 'Delayed'
GROUP BY instrument_type
ORDER BY Number_of_Delays DESC;
--Derivative and FX tend to be the instruments with very high delays

--Whats the average value of these delayed trades, adding monetary value to this risk(quantifying)
SELECT
	status,
	COUNT(*) AS NumberofTrades,
	AVG(amount) AS AverageTradeValue,
	SUM(amount) AS TotalValue
FROM [mock_trade_data ]
GROUP BY status


-- To do a trade reconciliation,
-- Simulate receiving a counterparty statement with errors
;WITH CounterpartyStatement AS (
    SELECT 
        trade_id,
        amount * 1.1 AS reported_amount -- They report a 10% higher amount
    FROM [mock_trade_data ]
    WHERE CAST(trade_id AS INT) % 100 = 0 -- Simulate getting data for only every 100th trade(to show how it might be real life)
)
-- Reconcile our records against their statement
SELECT 
    t.trade_id,
    t.counterparty,
    t.amount AS our_amount,
    cs.reported_amount AS their_amount,
    (t.amount - cs.reported_amount) AS discrepancy
FROM [mock_trade_data ] t
INNER JOIN CounterpartyStatement cs ON t.trade_id = cs.trade_id
WHERE t.amount != cs.reported_amount;

-- Since i've gotten the monetary value of the delays serving as the value of risk 
-- Now calculate the cost of each delay
SELECT
    -- Calculate how many business days late each trade is (assuming T+2 settlement)
    AVG(DATEDIFF(day, trade_date, settlement_date) - 2) AS avg_delay_days,
    -- Calculate the total value of money stuck per day
    SUM(amount) / NULLIF(SUM(DATEDIFF(day, trade_date, settlement_date) - 2), 0) AS value_stuck_per_day
FROM [mock_trade_data ]
WHERE status = 'Delayed';