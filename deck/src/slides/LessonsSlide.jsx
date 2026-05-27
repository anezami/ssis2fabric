import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import styles from './ContentSlide.module.css'

export default function LessonsSlide({ index }) {
  return (
    <Slide index={index} className={styles.slide}>
      <div className="accent-bar" />
      <div className="content-frame content-gutter">
        <div className={styles.shell}>
          <div className={styles.brandLine}>
            <span className={styles.microsoftMark} aria-hidden="true">
              <span /><span /><span /><span />
            </span>
            <Editable as="span" id="lessons.eyebrow">Lessons & gotchas</Editable>
          </div>

          <Editable as="h2" id="lessons.title" className={styles.title}>
            What we'd tell the next team to read first
          </Editable>

          <Editable as="p" id="lessons.lede" multiline className={styles.lede}>
            Concrete time-savers from building this end-to-end. If you skim nothing else
            in the repo, skim §7 of the README — these are the items that cost us hours
            the first time around.
          </Editable>

          <ul className={styles.list}>
            <li><strong>Fabric capacity ARM ID ≠ Fabric capacity GUID.</strong> Workspaces bind to the GUID returned by <span className={styles.code}>GET /v1/capacities</span>, not the Azure ARM resource ID. They look similar, they are not interchangeable.</li>
            <li><strong>Bastion Standard ≈ 30 min to provision.</strong> Plan the demo timeline around it; don't try to spin Bastion up live.</li>
            <li><strong>Fabric Warehouse T-SQL ≠ SQL Server T-SQL.</strong> No NVARCHAR, no IDENTITY, no DEFAULT NEWID(), no DEFAULT on built-ins, no CHECK constraints. The generator handles it; hand-authored T-SQL must.</li>
            <li><strong>COPY INTO from OneLake under a sqlcmd-passed AAD token fails with Msg 13840.</strong> Use a Fabric Data Pipeline copy activity in production; a pyodbc multi-row INSERT shim for demo scale.</li>
            <li><strong>Hand-authored DTSX can parse but still fail dtexec.</strong> OLE DB Source needs OpenRowset, Script Component needs a precompiled binary, Flat File Source needs FileNameColumnName, SourceCode arrays need arrayElementCount.</li>
            <li><strong>Notebook job failures report "System_Cancelled_Session_Statements_Failed" with no detail.</strong> Wrap each cell in try/except and persist <span className={styles.code}>traceback.format_exc()</span> to OneLake — the REST monitoring API does not surface cell stdout.</li>
          </ul>
        </div>
      </div>
      <BottomBar text={<Editable as="span" id="lessons.footer">Six gotchas that pay for themselves on the first migration</Editable>} />
    </Slide>
  )
}
