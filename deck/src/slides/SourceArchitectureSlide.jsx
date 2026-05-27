import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import styles from './ContentSlide.module.css'

export default function SourceArchitectureSlide({ index }) {
  return (
    <Slide index={index} className={styles.slide}>
      <div className="accent-bar" />
      <div className="content-frame content-gutter">
        <div className={styles.shell}>
          <div className={styles.brandLine}>
            <span className={styles.microsoftMark} aria-hidden="true">
              <span /><span /><span /><span />
            </span>
            <Editable as="span" id="source.eyebrow">Source architecture</Editable>
          </div>

          <Editable as="h2" id="source.title" className={styles.title}>
            A standard SSIS host on an Azure VM
          </Editable>

          <Editable as="p" id="source.lede" multiline className={styles.lede}>
            We provision a Windows Server VM in resource group
            <span className={styles.code}> rg-ssis2fabric-demo </span>
            (West US 3), with SQL Server 2022 Developer Edition and the SSIS feature
            installed. The three packages are deployed to the SSISDB catalog. Access is
            via Azure Bastion — no public RDP.
          </Editable>

          <div className={styles.diagram}>
            <div className={styles.flow}>
              <div className={styles.flowStep}>
                <span>Identity</span>
                Entra ID via Bastion
              </div>
              <div className={styles.flowArrow}>→</div>
              <div className={styles.flowStep}>
                <span>Compute</span>
                Azure VM (Windows)
              </div>
              <div className={styles.flowArrow}>→</div>
              <div className={styles.flowStep}>
                <span>Engine</span>
                SQL Server 2022 Dev + SSIS
              </div>
              <div className={styles.flowArrow}>→</div>
              <div className={styles.flowStep}>
                <span>Catalog</span>
                SSISDB · SsisDemo project
              </div>
            </div>
          </div>

          <ul className={styles.list}>
            <li><strong>Resource group:</strong> <span className={styles.code}>rg-ssis2fabric-demo</span> in West US 3.</li>
            <li><strong>SSISDB project:</strong> <span className={styles.code}>SsisDemo</span> — three packages, Project Deployment model.</li>
            <li><strong>Source databases:</strong> <span className={styles.code}>SalesSrc</span> (OLTP source) and <span className={styles.code}>SalesDW</span> (on-prem DW baseline).</li>
            <li><strong>Access:</strong> Azure Bastion Standard SKU only — no public IPs, no public RDP.</li>
          </ul>
        </div>
      </div>
      <BottomBar text={<Editable as="span" id="source.footer">A real SSIS estate, on Azure, behind Bastion — same shape as the customer's</Editable>} />
    </Slide>
  )
}
