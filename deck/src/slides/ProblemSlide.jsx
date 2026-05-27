import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import styles from './ContentSlide.module.css'

export default function ProblemSlide({ index }) {
  return (
    <Slide index={index} className={styles.slide}>
      <div className="accent-bar" />
      <div className="content-frame content-gutter">
        <div className={styles.shell}>
          <div className={styles.brandLine}>
            <span className={styles.microsoftMark} aria-hidden="true">
              <span /><span /><span /><span />
            </span>
            <Editable as="span" id="problem.eyebrow">The problem</Editable>
          </div>

          <Editable as="h2" id="problem.title" className={styles.title}>
            An aging SSIS estate. A modernization mandate. Two valid landing zones.
          </Editable>

          <Editable as="p" id="problem.lede" multiline className={styles.lede}>
            Enterprises still run SSIS for production ETL — .ispac packages, SSISDB catalogs,
            scheduled jobs. Modernizing to Microsoft Fabric is the obvious next step, but
            "which Fabric?" is a real question: Warehouse, Lakehouse, or both. This demo
            answers it by migrating the same SSIS workload onto each.
          </Editable>

          <div className={styles.cols3}>
            <div className={styles.card}>
              <span className={styles.cardEyebrow}>Today</span>
              <h3 className={styles.cardTitle}>SSIS on SQL Server</h3>
              <p className={styles.cardBody}>
                .ispac / .dtsx packages deployed to SSISDB. DBAs operate it. Logic is
                Execute SQL tasks, OLE DB sources, occasional Script Components.
              </p>
            </div>
            <div className={styles.card}>
              <span className={styles.cardEyebrow}>Path A</span>
              <h3 className={styles.cardTitle}>Fabric Warehouse</h3>
              <p className={styles.cardBody}>
                T-SQL stored procedures, MERGE-based SCD2, a single
                <span className={styles.code}>EXEC dw.usp_RunAll</span>. Familiar muscle
                memory for SQL-first teams.
              </p>
            </div>
            <div className={styles.card}>
              <span className={styles.cardEyebrow}>Path B</span>
              <h3 className={styles.cardTitle}>Fabric Lakehouse</h3>
              <p className={styles.cardBody}>
                PySpark notebook writing Delta tables to OneLake. Open format, accessible
                from any engine that speaks Delta. Data-engineering operating model.
              </p>
            </div>
          </div>
        </div>
      </div>
      <BottomBar text={<Editable as="span" id="problem.footer">Both paths are first-class in Fabric. Pick the team that will own it.</Editable>} />
    </Slide>
  )
}
