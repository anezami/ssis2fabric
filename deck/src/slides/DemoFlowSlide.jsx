import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import styles from './ContentSlide.module.css'

export default function DemoFlowSlide({ index }) {
  return (
    <Slide index={index} className={styles.slide}>
      <div className="accent-bar" />
      <div className="content-frame content-gutter">
        <div className={styles.shell}>
          <div className={styles.brandLine}>
            <span className={styles.microsoftMark} aria-hidden="true">
              <span /><span /><span /><span />
            </span>
            <Editable as="span" id="demo.eyebrow">Live demo</Editable>
          </div>

          <Editable as="h2" id="demo.title" className={styles.title}>
            Five steps, end to end
          </Editable>

          <Editable as="p" id="demo.lede" multiline className={styles.lede}>
            What you'll see in the live walkthrough — same playbook the README documents,
            same commands you'd run against your own SSIS estate.
          </Editable>

          <div className={styles.steps}>
            <div className={styles.step}>
              <strong>Open the source VM via Azure Bastion</strong>
              Browser-based RDP into the SSIS host in rg-ssis2fabric-demo. No public IP, Entra ID sign-in.
            </div>
            <div className={styles.step}>
              <strong>Show SSMS connected to SSISDB</strong>
              The SsisDemo project, three deployed packages, one project parameter.
            </div>
            <div className={styles.step}>
              <strong>Run the ssis-migration Copilot skill</strong>
              ssis-analyzer + dacpac-analyzer + spec-writer produce the JSON dumps and the Markdown spec set in migration/specs/.
            </div>
            <div className={styles.step}>
              <strong>Open the Fabric workspace</strong>
              The Warehouse (T-SQL files deployed, EXEC dw.usp_RunAll completed) and the Lakehouse (Delta tables under Tables/) both visible side by side.
            </div>
            <div className={styles.step}>
              <strong>Re-run the aggregate query</strong>
              Same SUM(TotalAmount) = $2,039,990.00 across source, Warehouse, and Lakehouse — live, from each endpoint.
            </div>
          </div>
        </div>
      </div>
      <BottomBar text={<Editable as="span" id="demo.footer">From SSISDB to OneLake in one sitting</Editable>} />
    </Slide>
  )
}
