import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import styles from './ContentSlide.module.css'

export default function DemoScopeSlide({ index }) {
  return (
    <Slide index={index} className={styles.slide}>
      <div className="accent-bar" />
      <div className="content-frame content-gutter">
        <div className={styles.shell}>
          <div className={styles.brandLine}>
            <span className={styles.microsoftMark} aria-hidden="true">
              <span /><span /><span /><span />
            </span>
            <Editable as="span" id="scope.eyebrow">Demo scope</Editable>
          </div>

          <Editable as="h2" id="scope.title" className={styles.title}>
            A small but realistic star schema. Three SSIS packages.
          </Editable>

          <Editable as="p" id="scope.lede" multiline className={styles.lede}>
            The source is a SalesSrc / SalesDW pair backing a tiny sales mart. Three SSIS
            packages load it: a straight customer dim, a CSV+Script-Component product dim,
            and a fact loader with a lookup join. Small enough to read end-to-end, real
            enough to exercise every migration surface.
          </Editable>

          <div className={styles.cols3}>
            <div className={styles.card}>
              <span className={styles.cardEyebrow}>Package 1</span>
              <h3 className={styles.cardTitle}>Load_Customers</h3>
              <p className={styles.cardBody}>
                Source → <span className={styles.code}>DimCustomer</span> with SCD2 close-and-insert.
                500 rows, 20 distinct countries.
              </p>
            </div>
            <div className={styles.card}>
              <span className={styles.cardEyebrow}>Package 2</span>
              <h3 className={styles.cardTitle}>Load_Products_Scripted</h3>
              <p className={styles.cardBody}>
                CSV source + Script Component (UPPER(Sku), derived margin_category) →
                <span className={styles.code}>DimProduct</span>. 100 rows, SUM(Price) = $23,199.50.
              </p>
            </div>
            <div className={styles.card}>
              <span className={styles.cardEyebrow}>Package 3</span>
              <h3 className={styles.cardTitle}>Load_Orders</h3>
              <p className={styles.cardBody}>
                Lookup join to both dims → <span className={styles.code}>FactOrders</span>.
                2,000 rows, SUM(TotalAmount) = $2,039,990.00.
              </p>
            </div>
          </div>

          <div className={styles.metrics}>
            <div className={styles.metric}>
              <span className={styles.metricValue}>500</span>
              <span className={styles.metricLabel}>DimCustomer rows · 20 countries</span>
            </div>
            <div className={styles.metric}>
              <span className={styles.metricValue}>100</span>
              <span className={styles.metricLabel}>DimProduct rows · $23,199.50 list value</span>
            </div>
            <div className={styles.metric}>
              <span className={styles.metricValue}>2,000</span>
              <span className={styles.metricLabel}>FactOrders rows · $2,039,990.00 sum</span>
            </div>
          </div>
        </div>
      </div>
      <BottomBar text={<Editable as="span" id="scope.footer">Three packages · one star schema · one number to match</Editable>} />
    </Slide>
  )
}
