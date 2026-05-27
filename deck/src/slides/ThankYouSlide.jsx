import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import { CopilotInFabricIcon, MicrosoftFabricIcon, PowerBIIcon } from '../data/fabric-icons.js'
import styles from './ThankYouSlide.module.css'

export default function ThankYouSlide({ index }) {
  return (
    <Slide index={index} className={styles.slide}>
      <div className="accent-bar" />

      <div className="content-frame content-gutter">
        <div className={styles.content}>
          <div className={styles.brandLockup}>
            <span className={styles.microsoftMark} aria-hidden="true">
              <span />
              <span />
              <span />
              <span />
            </span>
            <span>Microsoft Fabric</span>
          </div>

          <div className={styles.iconHalo} aria-hidden="true">
            <MicrosoftFabricIcon className={styles.heroIcon} fallback={<span className={styles.iconFallback}>F</span>} />
          </div>

          <Editable as="h2" id="thankYou.title" className={styles.title}>
            Your SSIS estate. Same playbook.
          </Editable>
          <Editable as="p" id="thankYou.subtitle" multiline className={styles.subtitle}>
            Bring your .ispac + source/target .bacpac. We run the ssis-migration skill,
            land the workload in Fabric — Warehouse, Lakehouse, or both — and prove parity
            with a single validation report. Repo: anezami/ssis2fabric.
          </Editable>

          <div className={styles.nextRow}>
            <div>
              <PowerBIIcon className={styles.nextIcon} fallback={<span className={styles.iconFallback}>BI</span>} />
              <span>Power BI-ready semantic layer</span>
            </div>
            <div>
              <CopilotInFabricIcon className={styles.nextIcon} fallback={<span className={styles.iconFallback}>AI</span>} />
              <span>Copilot-driven migration skill</span>
            </div>
          </div>
        </div>
      </div>

      <BottomBar text={<Editable as="span" id="thankYou.footer">anezami/ssis2fabric · github.com/markgar/ssis-migration · learn.microsoft.com/fabric</Editable>} />
    </Slide>
  )
}
