local lang = {
    modName = "Rise Enhanced",
    enabled = "Enabled",
    disabled = "Disabled",
    always = "Always enabled",
    loading = "Loading...",
    notification = "Enable notification",
    sounds = "Enable notification sounds",
    weaponType = "Weapon type",
    language = "Language",
    reset = "Reset to default",
    resetScriptNote = "Note: to toggle OFF requires a script reset after.",
    forceLoad = "Load \"%s\"",
    restartNote = "Note: to toggle OFF requires game restart after.",
    useDefault = "Use default: %s",
    secondText = "%s second",
    secondsText = "%s seconds",
    minuteText = "%s minute",
    minutesText = "%s minutes",
    skillText = "The skill %s has activated.",
    weaponNames = {
        [0] = "Great Sword",
        [1] = "Swtich Axe",
        [2] = "Long Sword",
        [3] = "Light Bowgun",
        [4] = "Heavy Bowgun",
        [5] = "Hammer",
        [6] = "Gunlance",
        [7] = "Lance",
        [8] = "Sword & Shield",
        [9] = "Dual Blades",
        [10] = "Hunting Horn",
        [11] = "Charge Blade",
        [12] = "Insect Glaive",
        [13] = "Bow",
    },
}

lang.Template = {
    name = "Template",
}

lang.Debug = {
    test = "Test",
    button = "[ --- DEBUG INFO --- ]",
}

lang.Config = {
    name = "Mod configuration",
    pixels = "%s px",
    xPos = "X position",
    yPos = "Y position",
    width = "Width",
    height = "Height",
    openState = "Show window by default",
    resetOnStart = "Reset window position and size on script reset",
    windowConfig = "Window configuration",
    debugConfig = "Debug window configuration",
    resetWindow = "Reset window position and size",
    resetWindowConfig = "Reset window configuration",
}

lang.Tweaks = {
    name = "Tweaks",
    noHitStop = "Disable hit stop",
    saveDelay = "Autosave delay",
    wirebugStart = "Start mission with a third wirebug (+30 secs duration)",
    wirebugRefresh = "Get a third wirebug on monster kill (+30 secs duration)",
    useMultipliers = "Use reward multipliers",
    configureMultipliers = "Configure reward multipliers",
    multipliers =  {
        "Money",
        "Kamura points",
        "Hunter rank",
        "Master rank",
        "Anomaly research"
    },
    useSmartMultipliers = "Use multipliers when lower than configured threshold",
    configureSmartThresh = "Configure multipliers thresholds",
}

lang.Tweaks.smartMultipliers =  {
    lang.Tweaks.multipliers[1],
    lang.Tweaks.multipliers[2],
    "HR experience",
    "MR experience",
    "Anomaly experience"
}

lang.Item = {
    name = "Item",
    autoRestock = "Restock items at quest start",
    largeMonsterRestock = "Restock after killing a large monster",
    useDefaultItemSet = "Use default",
    perWeapon = "Configure item loadout per weapon",
    restocked = "Restocked from: %s",
    emptyRadial = "Radial menu loadout is empty, skipped",
    radialApplied = "Radial menu set to: %s",
    emptySet = "Cannot restock from empty set",
    nilRadial = "Radial menu loadout not found",
    outOfStock = "Out of stock",
    usedItems = "Items used:",
    autoItems = "Use items automatically",
    infiniteItems = "Infinite items (only works with items consumed by this mod)",
    itemConfig = "Configure auto items",
    itemDuration = "Custom item duration",
    buffRefreshCd = "Buff refresh cooldown",
    customNote = "item duration is in minutes, buff cooldown is in seconds",
    itemList = {
        "Demondrug",
        "Mega Demondrug",
        "Might Seed",
        "Demon Powder",
        "Armorskin",
        "Mega Armorskin",
        "Adamant Seed",
        "Hardshell Powder",
        "Gourmet Fish",
        "Immunizer",
        "Dash Juice",
    },
    triggerList = {
        "Disabled",
        "Quest start",
        "Combat start",
        "Unsheathe weapon",
        "Always",
    }
}

lang.Dango = {
    name = "Dango",
    increasedChance = "Increase skill chance to 100% on ticket",
    infiniteTickets = "Infinite dango tickets",
    showAllDango = "Show all available dango (including daily)",
    hoppingSkewersLevels = "Configure hopping skewer levels",
    usableDangos = {
        "First dango",
        "Second dango",
        "Third dango"
    },
    autoEat = "Eat dango at quest start",
    defaultSet = "Default set",
    defaultCartSet = "Default cart set",
    dangoPerWeapon = "Use different dango set per weapon",
    useHoppingSkewers = "Use hopping skewers",
    usePoints = "Pay with kamura points",
    useTicket = "Use ticket by default",
    resetEatTimer = "Reset eating timer",
    disableTimer = "Disable eat timer (allows eating multiple times)",
    cartSet = "Eat different set when dying",
    perWeapon = "Dango set per weapon",
    perWeaponCart = "Dango set per weapon after cart",

    eatingFailed = "Dango module was unable to eat, please trigger eating manually",
    emptySet = "Cannot order from an empty set",
    eatMessage = "Ate \"%s\"",
    ticketRemaining = "%d tickets",
    outOufTickets = "out of tickets",
    hoppingSkewers = "Hopping skewer was used"
}

lang.Spiribirds = {
    name = "Spiribirds",
    health = "Health",
    stamina = "Stamina",
    attack = "Attack",
    defense = "Defense",
    spawnPrism = "Spawn prism spiribird",
    manual = "Manual spawn",
    healthButton = "   « Health »    ",
    staminaButton = "   « Stamina »   ",
    attackButton = "   « Attack »    ",
    defenseButton = "   « Defense »   ",
    rainbowButton = "                   « Prism »                     ",
    goldenButton = "                  « Golden »                    ",
}

lang.Weakness = {
    name = "Weakness Display",
    damageTypeShort = {
        "CUT",
        "BLN",
        "SHL",
        "FRE",
        "WTR",
        "ICE",
        "THD",
        "DRG",
    },
    onItembox = "Only show display when itembox is open",
    onCamp = "Show display inside quest camp",
    useElembane = "Use elembane rampage decoration for zone highlight",
    highlightExploitPhys = "Highlight weakness exploit zones",
    highlightExploitElem = "Highlight elemental exploit zones",
    highlightHighestPhys = "Highlight highest physical zones",
    highlightHighestElem = "Highlight highest elemental zones",
}

lang.Cheats = {
    name = "Cheats",
    unlimitedAmmo = "Unlimited HBG/LBG ammo",
    unlimitedCoatings = "Unlimited bow coatings",
}

return lang