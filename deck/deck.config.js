import CoverSlide from './src/slides/CoverSlide.jsx'
import ProblemSlide from './src/slides/ProblemSlide.jsx'
import DemoScopeSlide from './src/slides/DemoScopeSlide.jsx'
import SourceArchitectureSlide from './src/slides/SourceArchitectureSlide.jsx'
import MigrationToolSlide from './src/slides/MigrationToolSlide.jsx'
import WarehousePathSlide from './src/slides/WarehousePathSlide.jsx'
import LakehousePathSlide from './src/slides/LakehousePathSlide.jsx'
import ComparisonSlide from './src/slides/ComparisonSlide.jsx'
import ValidationSlide from './src/slides/ValidationSlide.jsx'
import DemoFlowSlide from './src/slides/DemoFlowSlide.jsx'
import LessonsSlide from './src/slides/LessonsSlide.jsx'
import ThankYouSlide from './src/slides/ThankYouSlide.jsx'

export default {
  id: 'ssis2fabric',
  title: 'SSIS → Microsoft Fabric',
  subtitle: 'Two migration paths. One working demo. End to end.',
  description: 'Reference migration of a classic SSIS workload to Microsoft Fabric — both the T-SQL Warehouse path and the PySpark Lakehouse path, validated to byte-identical aggregates.',
  meta: {
    contentStatus: 'final',
  },
  icon: '🛠',
  accent: '#49C5B1',
  theme: 'fabric',
  appearance: 'light',
  order: 1,
  slides: [
    CoverSlide,
    ProblemSlide,
    DemoScopeSlide,
    SourceArchitectureSlide,
    MigrationToolSlide,
    WarehousePathSlide,
    LakehousePathSlide,
    ComparisonSlide,
    ValidationSlide,
    DemoFlowSlide,
    LessonsSlide,
    ThankYouSlide,
  ],
}
