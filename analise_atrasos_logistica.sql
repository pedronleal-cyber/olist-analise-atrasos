-- Arquivo: analise_atrasos_logistica.sql
-- Objetivo: Identificar a origem dos atrasos nas entregas da Olist (Vendedor vs. Transportadora/Fase de Transporte)

SELECT
  status_vendedor,
  status_entrega_final,
  COUNT(*) AS total_pedidos,
  -- Calcula a representatividade percentual de cada cenário em relação ao total geral
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_do_total
FROM (
  SELECT
    o.order_id,
    -- Verifica se o vendedor entregou à transportadora após o limite estipulado
    CASE WHEN o.order_delivered_carrier_date > i.limite_vendedor_final
         THEN 'Atrasado' ELSE 'No Prazo' END AS status_vendedor,
    -- Verifica se o cliente recebeu após a data estimada (ignorando as horas para evitar falsos positivos)
    CASE WHEN date(o.order_delivered_customer_date) > date(o.order_estimated_delivery_date)
         THEN 'Atrasado' ELSE 'No Prazo' END AS status_entrega_final
  FROM olist_orders_dataset AS o
  JOIN (
    -- Subquery para consolidar itens de um mesmo pedido e garantir que haja apenas 1 vendedor por pedido
    SELECT order_id, MAX(shipping_limit_date) AS limite_vendedor_final
    FROM olist_order_items_dataset
    GROUP BY order_id
    HAVING COUNT(DISTINCT seller_id) = 1
  ) AS i ON o.order_id = i.order_id
  WHERE o.order_status = 'delivered'
    -- Filtros de limpeza: remoção de nulos e de inconsistências cronológicas (despacho antes da aprovação)
    AND o.order_approved_at IS NOT NULL
    AND o.order_delivered_carrier_date IS NOT NULL
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_delivered_carrier_date >= o.order_approved_at
) AS base
-- Agrupa a base tratada para gerar a matriz de cruzamento dos status
GROUP BY status_vendedor, status_entrega_final;
