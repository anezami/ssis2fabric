import { BottomBar, Editable, Slide } from '@deckio/deck-engine'
import styles from './ContentSlide.module.css'

export default function LakehousePathSlide({ index }) {
  return (
    <Slide index={index} className={styles.slide}>
      <div className="accent-bar" />
      <div className="content-frame content-gutter">
        <div className={styles.shell}>
          <div className={styles.brandLine}>
            <span className={styles.microsoftMark} aria-hidden="true">
              <span /><span /><span /><span />
            </span>
            <Editable as="span" id="lakehouse.eyebrow">Path B · Fabric Lakehouse</Editable>
          </div>

          <Editable as="h2" id="lakehouse.title" className={styles.title}>
            DTSX → PySpark notebook → Delta tables in OneLake
          </Editable>

          <div className={styles.diagram}>
            <div className={styles.flow}>
              <div className={styles.flowStep}><span>Input</span>.dtsx + .bacpac</div>
              <div className={styles.flowArrow}>→</div>
              <div className={styles.flowStep}><span>Analyzed</span>JSON specs</div>
              <div className={styles.flowArrow}>→</div>
              <div className={styles.flowStep}><span>Generated</span>migration.ipynb</div>
              <div className={styles.flowArrow}>→</div>
              <div className={styles.flowStep}><span>Runtime</span>RunNotebook job · Delta + SQL endpoint</div>
            </div>
          </div>

          <Editable as="p" id="lakehouse.lede" multiline className={styles.lede}>
            One generated PySpark notebook reads source parquet from OneLake, applies the
            same transformations the Script Component used to apply (e.g. UPPER(Sku),
            derive margin_category), builds dim_* with surrogate keys via window
            functions, builds fact_* with dim joins, writes Delta tables — and the
            Lakehouse SQL analytics endpoint exposes them as SparkSQL.
          </Editable>

          <ul className={styles.list}>
            <li><strong>Bound to the right lakehouse</strong> — uploader patches <span className={styles.code}>metadata.dependencies.lakehouse.default_lakehouse</span> before POST.</li>
            <li><strong>Doesn't depend on a "default lakehouse"</strong> — each table is written with <span className={styles.code}>.option("path", "abfss://…/Tables/&lt;name&gt;").saveAsTable(…)</span>.</li>
            <li><strong>Parquet timestamp gotcha:</strong> Fabric Spark refuses nanosecond timestamps — always write with <span className={styles.code}>coerce_timestamps="us"</span>.</li>
            <li><strong>SparkSQL string literals must be single-quoted</strong> — doubles are parsed as identifiers and silently break CASE expressions.</li>
            <li><strong>SQL endpoint lag:</strong> a fresh Delta write may return "Invalid object name" for 10–20 s; the validator retries.</li>
          </ul>
        </div>
      </div>
      <BottomBar text={<Editable as="span" id="lakehouse.footer">One notebook · Delta on OneLake · the same star schema, open format</Editable>} />
    </Slide>
  )
}
