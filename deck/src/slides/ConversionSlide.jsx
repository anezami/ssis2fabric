import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import styles from './ContentSlide.module.css'

export default function ConversionSlide({ index }) {
  return (
    <Slide index={index} className={styles.slide}>
      <div className="accent-bar" />
      <div className="content-frame content-gutter">
        <div className={styles.shell}>
          <div className={styles.brandLine}>
            <span className={styles.microsoftMark} aria-hidden="true">
              <span /><span /><span /><span />
            </span>
            <Editable as="span" id="conv.eyebrow">How the conversion works</Editable>
          </div>

          <Editable as="h2" id="conv.title" className={styles.title}>
            SSIS components → T-SQL (Warehouse) or SparkSQL (Lakehouse)
          </Editable>

          <Editable as="p" id="conv.lede" multiline className={styles.lede}>
            The skill parses DTSX XML into an intermediate representation, then emits
            target-shaped artifacts. Every SSIS construct has a deterministic mapping
            on each side — Data Flow becomes either a Fabric Pipeline + stored procs,
            or a PySpark cell that writes Delta.
          </Editable>

          <table className={styles.table}>
            <thead>
              <tr>
                <th>SSIS component</th>
                <th>Fabric Warehouse (T-SQL)</th>
                <th>Fabric Lakehouse (SparkSQL / PySpark)</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><strong>OLE DB Source</strong></td>
                <td>Pipeline <em>Copy Activity</em> → staging table</td>
                <td><span className={styles.code}>spark.read.jdbc(...)</span> / <span className={styles.code}>parquet</span></td>
              </tr>
              <tr>
                <td><strong>OLE DB Destination</strong></td>
                <td><span className={styles.code}>INSERT … SELECT</span> / <span className={styles.code}>MERGE</span></td>
                <td><span className={styles.code}>df.write.format("delta")</span></td>
              </tr>
              <tr>
                <td><strong>Derived Column</strong></td>
                <td><span className={styles.code}>CASE WHEN</span> in projection</td>
                <td><span className={styles.code}>df.withColumn(when(...))</span></td>
              </tr>
              <tr>
                <td><strong>Lookup</strong></td>
                <td><span className={styles.code}>LEFT JOIN</span> on staging</td>
                <td>DataFrame <span className={styles.code}>join(dim, "key", "left")</span></td>
              </tr>
              <tr>
                <td><strong>Conditional Split</strong></td>
                <td>Branched <span className={styles.code}>WHERE</span> / multiple INSERTs</td>
                <td><span className={styles.code}>df.filter(...)</span> per branch</td>
              </tr>
              <tr>
                <td><strong>Aggregate</strong></td>
                <td><span className={styles.code}>GROUP BY</span> / window funcs</td>
                <td><span className={styles.code}>groupBy().agg(...)</span></td>
              </tr>
              <tr>
                <td><strong>Foreach Loop</strong></td>
                <td>Pipeline <span className={styles.code}>ForEach</span> activity</td>
                <td>Python <span className={styles.code}>for</span> over a list</td>
              </tr>
              <tr>
                <td><strong>Execute SQL Task</strong></td>
                <td>Stored procedure call</td>
                <td><span className={styles.code}>spark.sql("...")</span></td>
              </tr>
              <tr>
                <td><strong>Script Task / Component</strong></td>
                <td>Stored proc or pipeline notebook</td>
                <td>Native PySpark cell</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      <BottomBar text={<Editable as="span" id="conv.footer">Deterministic mapping · same business logic · two execution surfaces</Editable>} />
    </Slide>
  )
}
