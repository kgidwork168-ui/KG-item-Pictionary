-- OPTIONAL: RUN THIS ONLY IF YOU ALREADY USED THE FIRST KG catalogue database.
-- It copies the old single Size / Colour / Price into the new product_variants table.
-- Safe to run more than once: it skips products that already have a variant.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='products' AND column_name='price'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='products' AND column_name='size_text'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='products' AND column_name='colors_text'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='products' AND column_name='price_unit'
  ) THEN
    EXECUTE $sql$
      insert into public.product_variants(product_id,size_text,color_text,price,price_unit,sort_order)
      select p.id,p.size_text,p.colors_text,p.price,p.price_unit,10
      from public.products p
      where p.price is not null
        and not exists(select 1 from public.product_variants v where v.product_id=p.id)
    $sql$;
  END IF;
END $$;
