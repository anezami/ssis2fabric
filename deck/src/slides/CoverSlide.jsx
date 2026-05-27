import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import { CopilotInFabricIcon, MicrosoftFabricIcon, OneLakeIcon, PowerBIIcon } from '../data/fabric-icons.js'
import styles from './CoverSlide.module.css'

export default function CoverSlide() {
  return (
    <Slide index={0} className={styles.cover}>
      <div className="accent-bar" />

      <div className="content-frame content-gutter">
        <div className={styles.shell}>
          <section className={styles.content}>
            <div className={styles.brandLine}>
              <span className={styles.microsoftMark} aria-hidden="true">
                <span />
                <span />
                <span />
                <span />
              </span>
              <Editable as="span" id="cover.eyebrow">Microsoft Fabric</Editable>
            </div>

            <h1>
              <Editable as="span" id="cover.title">SSIS → Microsoft Fabric</Editable>
            </h1>

            <Editable as="p" id="cover.subtitle" multiline className={styles.subtitle}>
              Two migration paths. One working demo. End to end.
            </Editable>

            <div className={styles.meta}>
              <div>
                <span className={styles.metaLabel}>Path A</span>
                <span className={styles.metaValue}>Fabric Warehouse (T-SQL)</span>
              </div>
              <div>
                <span className={styles.metaLabel}>Path B</span>
                <span className={styles.metaValue}>Fabric Lakehouse (PySpark)</span>
              </div>
              <div>
                <span className={styles.metaLabel}>Presenter</span>
                <span className={styles.metaValue}>arnezami</span>
              </div>
            </div>
          </section>

          <aside className={styles.fabricPanel} aria-label="Microsoft Fabric workloads">
            <div className={styles.panelHeader}>
              <MicrosoftFabricIcon className={styles.fabricIcon} fallback={<span className={styles.iconFallback}>F</span>} />
              <span>Fabric workload map</span>
            </div>
            <div className={styles.workloadStack}>
              <div className={styles.workload}>
                <OneLakeIcon className={styles.workloadIcon} fallback={<span className={styles.iconFallback}>OL</span>} />
                <span>OneLake</span>
              </div>
              <div className={styles.workload}>
                <PowerBIIcon className={styles.workloadIcon} fallback={<span className={styles.iconFallback}>BI</span>} />
                <span>Power BI</span>
              </div>
              <div className={styles.workload}>
                <CopilotInFabricIcon className={styles.workloadIcon} fallback={<span className={styles.iconFallback}>AI</span>} />
                <span>Copilot in Fabric</span>
              </div>
            </div>
          </aside>
        </div>
      </div>

      <BottomBar text={<Editable as="span" id="cover.footer">SSIS → Microsoft Fabric reference migration · anezami/ssis2fabric</Editable>} />
    </Slide>
  )
}
