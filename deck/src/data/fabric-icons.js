/**
 * Microsoft Fabric Icons Helper
 *
 * Fabric-themed decks get @fabric-msft/svg-icons as a dependency and this
 * helper is copied into src/data/fabric-icons.js. The package is browser-first
 * and expects window during module evaluation. Icons are lazy-loaded on demand
 * when components mount — Vite-ignored dynamic imports prevent them from
 * bloating the optimizeDeps pre-bundling step at cold boot.
 */
import React from 'react'

const ICON_LOADERS = {
  Fabric32Color: () => import(/* @vite-ignore */ '@fabric-msft/svg-icons/dist/Fabric32Color.js').then((module) => module.default),
  PowerBi32Color: () => import(/* @vite-ignore */ '@fabric-msft/svg-icons/dist/PowerBi32Color.js').then((module) => module.default),
  DataFactory32Color: () => import(/* @vite-ignore */ '@fabric-msft/svg-icons/dist/DataFactory32Color.js').then((module) => module.default),
  DataEngineering32Color: () => import(/* @vite-ignore */ '@fabric-msft/svg-icons/dist/DataEngineering32Color.js').then((module) => module.default),
  DataWarehouse32Color: () => import(/* @vite-ignore */ '@fabric-msft/svg-icons/dist/DataWarehouse32Color.js').then((module) => module.default),
  DataScience32Color: () => import(/* @vite-ignore */ '@fabric-msft/svg-icons/dist/DataScience32Color.js').then((module) => module.default),
  SqlDatabase32Item: () => import(/* @vite-ignore */ '@fabric-msft/svg-icons/dist/SqlDatabase32Item.js').then((module) => module.default),
  RealTimeIntelligence32Color: () => import(/* @vite-ignore */ '@fabric-msft/svg-icons/dist/RealTimeIntelligence32Color.js').then((module) => module.default),
  GraphIntelligence32Color: () => import(/* @vite-ignore */ '@fabric-msft/svg-icons/dist/GraphIntelligence32Color.js').then((module) => module.default),
  Copilot32Color: () => import(/* @vite-ignore */ '@fabric-msft/svg-icons/dist/Copilot32Color.js').then((module) => module.default),
  OneLake32Color: () => import(/* @vite-ignore */ '@fabric-msft/svg-icons/dist/OneLake32Color.js').then((module) => module.default),
}

const ICON_EXPORTS = Object.keys(ICON_LOADERS)

let iconModule = null
let iconModulePromise = null

export function preloadFabricIcons() {
  if (iconModule) {
    return Promise.resolve(iconModule)
  }

  if (typeof window === 'undefined') {
    return Promise.resolve(null)
  }

  if (!iconModulePromise) {
    iconModulePromise = Promise.all(
      Object.entries(ICON_LOADERS).map(async ([iconId, loadIcon]) => [iconId, await loadIcon()]),
    )
      .then((entries) => {
        iconModule = Object.fromEntries(entries)
        return iconModule
      })
      .catch((error) => {
        iconModulePromise = null
        throw error
      })
  }

  return iconModulePromise
}

function getCachedIconComponent(iconId) {
  return iconModule?.[iconId] || null
}

function FabricIconRenderer({ iconId, fallback = null, ...props }) {
  const [Icon, setIcon] = React.useState(() => getCachedIconComponent(iconId))

  React.useEffect(() => {
    let cancelled = false

    if (Icon) {
      return undefined
    }

    preloadFabricIcons()
      .then((module) => {
        if (!cancelled) {
          setIcon(() => module?.[iconId] || null)
        }
      })
      .catch((error) => {
        console.warn(`[deckio] Unable to load Fabric icon "${iconId}".`, error)
      })

    return () => {
      cancelled = true
    }
  }, [Icon, iconId])

  if (!Icon) {
    return fallback
  }

  return React.createElement(Icon, { viewBox: '0 0 32 32', ...props })
}

function createFabricIconComponent(iconId, displayName) {
  function FabricIconComponent(props) {
    return React.createElement(FabricIconRenderer, { ...props, iconId })
  }

  FabricIconComponent.displayName = displayName
  FabricIconComponent.fabricIconId = iconId

  return FabricIconComponent
}

export const MicrosoftFabricIcon = createFabricIconComponent('Fabric32Color', 'MicrosoftFabricIcon')
export const FabricIcon = MicrosoftFabricIcon
export const PowerBIIcon = createFabricIconComponent('PowerBi32Color', 'PowerBIIcon')
export const DataFactoryIcon = createFabricIconComponent('DataFactory32Color', 'DataFactoryIcon')
export const DataEngineeringIcon = createFabricIconComponent('DataEngineering32Color', 'DataEngineeringIcon')
export const DataWarehouseIcon = createFabricIconComponent('DataWarehouse32Color', 'DataWarehouseIcon')
export const DataScienceIcon = createFabricIconComponent('DataScience32Color', 'DataScienceIcon')
export const DatabasesIcon = createFabricIconComponent('SqlDatabase32Item', 'DatabasesIcon')
export const RealTimeIntelligenceIcon = createFabricIconComponent('RealTimeIntelligence32Color', 'RealTimeIntelligenceIcon')
export const FabricIQIcon = createFabricIconComponent('GraphIntelligence32Color', 'FabricIQIcon')
export const CopilotInFabricIcon = createFabricIconComponent('Copilot32Color', 'CopilotInFabricIcon')
export const OneLakeIcon = createFabricIconComponent('OneLake32Color', 'OneLakeIcon')

const ICON_COMPONENTS = {
  Fabric32Color: MicrosoftFabricIcon,
  PowerBi32Color: PowerBIIcon,
  DataFactory32Color: DataFactoryIcon,
  DataEngineering32Color: DataEngineeringIcon,
  DataWarehouse32Color: DataWarehouseIcon,
  DataScience32Color: DataScienceIcon,
  SqlDatabase32Item: DatabasesIcon,
  RealTimeIntelligence32Color: RealTimeIntelligenceIcon,
  GraphIntelligence32Color: FabricIQIcon,
  Copilot32Color: CopilotInFabricIcon,
  OneLake32Color: OneLakeIcon,
}

export const FABRIC_WORKLOAD_ICONS = {
  // Core Fabric platform
  'microsoft-fabric': {
    name: 'Microsoft Fabric',
    iconId: 'Fabric32Color',
    Icon: MicrosoftFabricIcon,
    description: 'Unified analytics platform',
  },
  'fabric': {
    name: 'Fabric',
    iconId: 'Fabric32Color',
    Icon: FabricIcon,
    description: 'Microsoft Fabric platform',
  },

  // Data & Analytics workloads
  'power-bi': {
    name: 'Microsoft Power BI',
    shortName: 'Power BI',
    iconId: 'PowerBi32Color',
    Icon: PowerBIIcon,
    description: 'Business intelligence and analytics',
  },
  'data-factory': {
    name: 'Fabric Data Factory',
    iconId: 'DataFactory32Color',
    Icon: DataFactoryIcon,
    description: 'Data integration and orchestration',
  },
  'data-engineering': {
    name: 'Fabric Data Engineering',
    iconId: 'DataEngineering32Color',
    Icon: DataEngineeringIcon,
    description: 'Spark-based data engineering',
  },
  'data-warehouse': {
    name: 'Fabric Data Warehouse',
    iconId: 'DataWarehouse32Color',
    Icon: DataWarehouseIcon,
    description: 'Enterprise data warehousing',
  },
  'data-science': {
    name: 'Fabric Data Science',
    iconId: 'DataScience32Color',
    Icon: DataScienceIcon,
    description: 'ML and data science workloads',
  },
  'databases': {
    name: 'Fabric Databases',
    iconId: 'SqlDatabase32Item',
    Icon: DatabasesIcon,
    description: 'Database services in Fabric',
  },
  'real-time-intelligence': {
    name: 'Fabric Real-Time Intelligence',
    iconId: 'RealTimeIntelligence32Color',
    Icon: RealTimeIntelligenceIcon,
    description: 'Real-time analytics and streaming',
  },

  // AI & Intelligence
  'fabric-iq': {
    name: 'Fabric IQ',
    iconId: 'GraphIntelligence32Color',
    Icon: FabricIQIcon,
    description: 'Fabric intelligence and insights',
  },
  'copilot-fabric': {
    name: 'Copilot in Microsoft Fabric',
    shortName: 'Copilot in Fabric',
    iconId: 'Copilot32Color',
    Icon: CopilotInFabricIcon,
    description: 'AI assistant for Microsoft Fabric',
  },

  // Storage & Foundation
  'onelake': {
    name: 'Microsoft OneLake',
    shortName: 'OneLake',
    iconId: 'OneLake32Color',
    Icon: OneLakeIcon,
    description: 'Unified data lake for Fabric',
  },
}

/**
 * Helper function to get an icon reference by key.
 *
 * @param {string} key - Icon key from FABRIC_WORKLOAD_ICONS
 * @returns {object|null} Icon metadata or null if not found
 *
 * @example
 * const fabricIcon = getFabricIcon('microsoft-fabric')
 * console.log(fabricIcon.name) // "Microsoft Fabric"
 */
export function getFabricIcon(key) {
  return FABRIC_WORKLOAD_ICONS[key] || null
}

/**
 * Get all available Fabric workload icon keys.
 *
 * @returns {string[]} Array of icon keys
 */
export function getFabricIconKeys() {
  return Object.keys(FABRIC_WORKLOAD_ICONS)
}

/**
 * Returns a preloaded wrapper component by export name.
 *
 * @param {string} iconId - Export name such as "Fabric32Color"
 * @returns {Promise<Function|null>} Icon component or null if not mapped
 */
export async function loadFabricIconSVG(iconId) {
  if (!ICON_EXPORTS.includes(iconId)) {
    return null
  }

  const module = await preloadFabricIcons()
  return module?.[iconId] || ICON_COMPONENTS[iconId] || null
}

/**
 * Check if @fabric-msft/svg-icons can be loaded in the current runtime.
 *
 * @returns {Promise<boolean>} True when official Fabric icons are available
 */
export async function isFabricIconsAvailable() {
  const module = await preloadFabricIcons()
  return Boolean(module)
}

export default FABRIC_WORKLOAD_ICONS
