import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import styles from './ContentSlide.module.css'

export default function MigrationToolSlide({ index }) {
  return (
    <Slide index={index} className={styles.slide}>
      <div className="accent-bar" />
      <div className="content-frame content-gutter">
        <div className={styles.shell}>
          <div className={styles.brandLine}>
            <span className={styles.microsoftMark} aria-hidden="true">
              <span /><span /><span /><span />
            </span>
            <Editable as="span" id="tool.eyebrow">Migration tool</Editable>
          </div>

          <Editable as="h2" id="tool.title" className={styles.title}>
            The <span className={styles.code}>ssis-migration</span> Copilot skill
          </Editable>

          <Editable as="p" id="tool.lede" multiline className={styles.lede}>
            A three-plugin Copilot skill that drives the conversion: it reads the .ispac /
            .dtsx and .bacpac inputs, extracts everything the migration needs to know, and
            writes a runtime-agnostic spec set. Both Fabric build passes start from those
            specs.
          </Editable>

          <div className={styles.cols3}>
            <div className={styles.card}>
              <span className={styles.cardEyebrow}>Plugin 1</span>
              <h3 className={styles.cardTitle}>ssis-analyzer</h3>
              <p className={styles.cardBody}>
                Parses DTSX XML — control flow, data flows, precedence constraints,
                Execute SQL bodies, Script Task code, connection managers, column lineage.
              </p>
            </div>
            <div className={styles.card}>
              <span className={styles.cardEyebrow}>Plugin 2</span>
              <h3 className={styles.cardTitle}>dacpac-analyzer</h3>
              <p className={styles.cardBody}>
                Same job for .bacpac: tables, columns, types, indexes, views, stored
                procedures, functions, PK/FK/check/default constraints, roles, permissions.
              </p>
            </div>
            <div className={styles.card}>
              <span className={styles.cardEyebrow}>Plugin 3</span>
              <h3 className={styles.cardTitle}>spec-writer</h3>
              <p className={styles.cardBody}>
                Prose synthesis: emits a CONSTITUTION + one Markdown spec per dim / fact
                table, each carrying SSIS lineage, source SQL, SCD2 logic, and per-flavor
                build notes.
              </p>
            </div>
          </div>

          <ul className={styles.list}>
            <li><strong>Install:</strong> <span className={styles.code}>/marketplace add https://github.com/markgar/ssis-migration</span> in the Copilot CLI, then <span className={styles.code}>/plugins install</span> each plugin.</li>
            <li><strong>Runtime:</strong> Pure Python stdlib — no pip install needed.</li>
            <li><strong>Output:</strong> JSON dumps under <span className={styles.code}>migration/source-analysis/</span> and <span className={styles.code}>migration/dacpac-analysis/</span>, plus Markdown specs in <span className={styles.code}>migration/specs/</span>.</li>
          </ul>
        </div>
      </div>
      <BottomBar text={<Editable as="span" id="tool.footer">github.com/markgar/ssis-migration · the same skill drives every migration in this demo</Editable>} />
    </Slide>
  )
}
