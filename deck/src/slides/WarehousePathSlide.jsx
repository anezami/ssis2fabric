import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import styles from './ContentSlide.module.css'

export default function WarehousePathSlide({ index }) {
  return (
    <Slide index={index} className={styles.slide}>
      <div className="accent-bar" />
      <div className="content-frame content-gutter">
        <div className={styles.shell}>
          <div className={styles.brandLine}>
            <span className={styles.microsoftMark} aria-hidden="true">
              <span /><span /><span /><span />
            </span>
            <Editable as="span" id="warehouse.eyebrow">Path A · Fabric Warehouse</Editable>
          </div>

          <Editable as="h2" id="warehouse.title" className={styles.title}>
            DTSX → T-SQL stored procedures → Fabric Warehouse
          </Editable>

          <div className={styles.diagram}>
            <div className={styles.flow}>
              <div className={styles.flowStep}><span>Input</span>.dtsx + .bacpac</div>
              <div className={styles.flowArrow}>→</div>
              <div className={styles.flowStep}><span>Analyzed</span>JSON specs</div>
              <div className={styles.flowArrow}>→</div>
              <div className={styles.flowStep}><span>Generated</span>5 .sql files</div>
              <div className={styles.flowArrow}>→</div>
              <div className={styles.flowStep}><span>Runtime</span>EXEC dw.usp_RunAll</div>
            </div>
          </div>

          <Editable as="p" id="warehouse.lede" multiline className={styles.lede}>
            Five generated T-SQL files build schemas, staging tables, dim/fact tables, one
            stored procedure per entity (SCD2 MERGE for dims, lookup-join INSERT for the
            fact), and a single orchestrator. The Warehouse T-SQL surface differs from box
            SQL Server — the generator already accounts for it.
          </Editable>

          <ul className={styles.list}>
            <li><strong>No NVARCHAR</strong> — use <span className={styles.code}>VARCHAR</span> (UTF-8 by default).</li>
            <li><strong>No IDENTITY / DEFAULT NEWID() / DEFAULT on built-ins / CHECK constraints</strong> — surrogate keys via <span className={styles.code}>ROW_NUMBER()</span>; materialize defaults at load.</li>
            <li><strong>MERGE is supported</strong> — SCD2 close-then-insert translates cleanly.</li>
            <li><strong>COPY INTO + sqlcmd token</strong> fails with <span className={styles.code}>Msg 13840</span> (no OBO to OneLake). Demo uses <span className={styles.code}>pyodbc</span> + multi-row INSERT VALUES; production uses Fabric Data Pipeline copy activity.</li>
            <li><strong>OneLake binary upload:</strong> use the DFS REST API directly (PUT → PATCH append → PATCH flush) with a <span className={styles.code}>storage.azure.com</span>-scoped token.</li>
          </ul>
        </div>
      </div>
      <BottomBar text={<Editable as="span" id="warehouse.footer">Five .sql files · one EXEC · the SSIS shape, in Warehouse T-SQL</Editable>} />
    </Slide>
  )
}
