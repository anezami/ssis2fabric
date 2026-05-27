import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import styles from './E2EFlowSlide.module.css'

export default function E2EFlowSlide({ index }) {
  return (
    <Slide index={index} className={styles.slide}>
      <div className="accent-bar" />
      <div className="content-frame content-gutter">
        <div className={styles.shell}>
          <div className={styles.brandLine}>
            <span className={styles.microsoftMark} aria-hidden="true">
              <span /><span /><span /><span />
            </span>
            <Editable as="span" id="e2e.eyebrow">End-to-end flow</Editable>
          </div>

          <Editable as="h2" id="e2e.title" className={styles.title}>
            From SSIS on a VM to two live Fabric workloads — one pipeline
          </Editable>

          <Editable as="p" id="e2e.lede" multiline className={styles.lede}>
            One Azure VM runs the legacy SSIS estate. The ssis-migration Copilot skill
            reads its packages and emits a single spec set. From there, two parallel
            build passes deploy the same logic into a Fabric Warehouse and a Fabric
            Lakehouse — both governed by the same workspace.
          </Editable>

          <div className={styles.diagramCard}>
            <div className={styles.row}>
              <div className={`${styles.node} ${styles.nodeSource}`}>
                <span className={styles.nodeKicker}>Source · Azure VM</span>
                <strong>SQL Server 2022 + SSIS</strong>
                <em>.ispac · .dtsx · SSISDB</em>
              </div>
              <div className={styles.arrow}>→</div>
              <div className={`${styles.node} ${styles.nodeTool}`}>
                <span className={styles.nodeKicker}>Convert · Copilot</span>
                <strong>ssis-migration skill</strong>
                <em>analyzer · dacpac · spec-writer</em>
              </div>
              <div className={styles.arrow}>→</div>
              <div className={`${styles.node} ${styles.nodeSpec}`}>
                <span className={styles.nodeKicker}>IR · One spec set</span>
                <strong>Constitution + per-table specs</strong>
                <em>shared by both targets</em>
              </div>
            </div>

            <div className={styles.fanout}>
              <div className={styles.fanArm} aria-hidden="true" />
              <div className={styles.fanArm} aria-hidden="true" />
            </div>

            <div className={styles.row}>
              <div className={`${styles.node} ${styles.nodeWarehouse}`}>
                <span className={styles.nodeKicker}>Path A · T-SQL</span>
                <strong>Fabric Warehouse</strong>
                <em>CREATE TABLE · MERGE · usp_RunAll · Data Pipeline</em>
              </div>
              <div className={`${styles.node} ${styles.nodeLakehouse}`}>
                <span className={styles.nodeKicker}>Path B · SparkSQL</span>
                <strong>Fabric Lakehouse</strong>
                <em>PySpark notebook · Delta on OneLake · SparkSQL</em>
              </div>
            </div>

            <div className={styles.fanout}>
              <div className={styles.fanJoin} aria-hidden="true" />
            </div>

            <div className={styles.row}>
              <div className={`${styles.node} ${styles.nodeWorkspace}`}>
                <span className={styles.nodeKicker}>Deployed</span>
                <strong>Fabric Workspace · ws-ssis2fabric-demo</strong>
                <em>byte-identical aggregates · validated end-to-end</em>
              </div>
            </div>
          </div>
        </div>
      </div>
      <BottomBar text={<Editable as="span" id="e2e.footer">One source · one spec set · two Fabric targets · one validated outcome</Editable>} />
    </Slide>
  )
}
