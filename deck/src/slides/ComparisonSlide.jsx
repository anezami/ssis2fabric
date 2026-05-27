import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import styles from './ContentSlide.module.css'

export default function ComparisonSlide({ index }) {
  return (
    <Slide index={index} className={styles.slide}>
      <div className="accent-bar" />
      <div className="content-frame content-gutter">
        <div className={styles.shell}>
          <div className={styles.brandLine}>
            <span className={styles.microsoftMark} aria-hidden="true">
              <span /><span /><span /><span />
            </span>
            <Editable as="span" id="compare.eyebrow">Side-by-side</Editable>
          </div>

          <Editable as="h2" id="compare.title" className={styles.title}>
            When to choose which
          </Editable>

          <Editable as="p" id="compare.lede" multiline className={styles.lede}>
            Both flavors are first-class in Fabric, both bill against the same capacity,
            both write to OneLake. The choice is mostly about the team that will own the
            pipeline — and many enterprises end up running both.
          </Editable>

          <table className={styles.table}>
            <thead>
              <tr>
                <th>Dimension</th>
                <th>Fabric Warehouse (Path A)</th>
                <th>Fabric Lakehouse (Path B)</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><strong>Skill set</strong></td>
                <td>T-SQL, stored procedures, MERGE</td>
                <td>PySpark notebooks, Delta, DataFrames</td>
              </tr>
              <tr>
                <td><strong>Downstream</strong></td>
                <td>Power BI semantic model, Direct Lake / DirectQuery</td>
                <td>ML pipelines, Spark jobs, anything that reads Delta</td>
              </tr>
              <tr>
                <td><strong>Governance</strong></td>
                <td>SQL-style RBAC, single governed SQL endpoint</td>
                <td>OneLake permissions, open Delta accessible from anywhere</td>
              </tr>
              <tr>
                <td><strong>SSIS fit</strong></td>
                <td>Mostly Execute SQL / OLE DB sources</td>
                <td>Script Components, complex transforms, semi-structured data</td>
              </tr>
              <tr>
                <td><strong>Operations</strong></td>
                <td>DBAs operate the warehouse</td>
                <td>Platform engineers operate notebooks + pipelines</td>
              </tr>
              <tr>
                <td><strong>Openness</strong></td>
                <td>Closed SQL surface (with T-SQL gotchas)</td>
                <td>Open Delta on OneLake — portable</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      <BottomBar text={<Editable as="span" id="compare.footer">Many teams land raw in the Lakehouse and curate into the Warehouse</Editable>} />
    </Slide>
  )
}
