import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import styles from './ContentSlide.module.css'

export default function ConversionExampleSlide({ index }) {
  return (
    <Slide index={index} className={styles.slide}>
      <div className="accent-bar" />
      <div className="content-frame content-gutter">
        <div className={styles.shell}>
          <div className={styles.brandLine}>
            <span className={styles.microsoftMark} aria-hidden="true">
              <span /><span /><span /><span />
            </span>
            <Editable as="span" id="convx.eyebrow">Worked example</Editable>
          </div>

          <Editable as="h2" id="convx.title" className={styles.title}>
            One Derived Column expression, three forms
          </Editable>

          <Editable as="p" id="convx.lede" multiline className={styles.lede}>
            A typical SSIS Derived Column tagging customers by total spend. The skill
            keeps the same semantics on both Fabric paths — only the surface changes.
          </Editable>

          <div className={styles.cols3}>
            <div className={styles.card}>
              <span className={styles.cardEyebrow}>SSIS · Derived Column</span>
              <h3 className={styles.cardTitle}>Expression</h3>
              <pre><code>{`Tier =
  TotalSpend > 10000 ?
    "Platinum" :
  TotalSpend > 5000 ?
    "Gold" :
    "Standard"`}</code></pre>
            </div>

            <div className={styles.card}>
              <span className={styles.cardEyebrow}>Warehouse · T-SQL</span>
              <h3 className={styles.cardTitle}>CASE in projection</h3>
              <pre><code>{`SELECT
  CustomerKey,
  CASE
    WHEN TotalSpend > 10000 THEN 'Platinum'
    WHEN TotalSpend >  5000 THEN 'Gold'
    ELSE                         'Standard'
  END AS Tier
FROM stg.Customer;`}</code></pre>
            </div>

            <div className={styles.card}>
              <span className={styles.cardEyebrow}>Lakehouse · SparkSQL</span>
              <h3 className={styles.cardTitle}>withColumn / SQL</h3>
              <pre><code>{`df = df.withColumn(
  "Tier",
  when(col("TotalSpend") > 10000, "Platinum")
    .when(col("TotalSpend") >  5000, "Gold")
    .otherwise("Standard"),
)
df.write.format("delta")
  .mode("overwrite").save(path)`}</code></pre>
            </div>
          </div>
        </div>
      </div>
      <BottomBar text={<Editable as="span" id="convx.footer">Same semantics · T-SQL CASE on Warehouse · when()/otherwise() on Lakehouse</Editable>} />
    </Slide>
  )
}
