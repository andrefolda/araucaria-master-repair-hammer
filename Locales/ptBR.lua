local _, ns = ...

ns.Locales = ns.Locales or {}
ns.Locales["ptBR"] = {
    ADDON_NAME                    = "Araucaria Martelo de Reparo do Mestre",

    DURABILITY_THRESHOLD_SETTINGS = "Configurações de Limiar de Durabilidade",
    SHOW_DURABILITY               = "Exibir Durabilidade",
    LOW_DURABILITY                = "Durabilidade Baixa",
    CRITICAL_DURABILITY           = "Durabilidade Crítica",

    ICON_SETTINGS                 = "Configurações de Ícone",
    ORIENTATION                   = "Orientação",
    ICON_SIZE                     = "Tamanho do Ícone",
    ORIENTATION_HORIZONTAL_CENTER = "Horizontal - Centralizado",
    ORIENTATION_HORIZONTAL_LTR    = "Horizontal - Esquerda para Direita",
    ORIENTATION_HORIZONTAL_RTL    = "Horizontal - Direita para Esquerda",
    ORIENTATION_VERTICAL_CENTER   = "Vertical - Centralizado",
    ORIENTATION_VERTICAL_TTB      = "Vertical - Cima para Baixo",
    ORIENTATION_VERTICAL_BTT      = "Vertical - Baixo para Cima",

    DURABILITY_TEXT_SETTINGS      = "Configurações de Texto de Durabilidade",
    SIZE                          = "Tamanho",
    FONT                          = "Fonte",
    X_OFFSET                      = "Deslocamento X",
    Y_OFFSET                      = "Deslocamento Y",

    SHOW_ONLY_REPAIRABLE          = "Exibir Apenas Reparáveis",
    SHOW_ONLY_REPAIRABLE_TOOLTIP  = "Exibe apenas os slots de equipamento que seu Martelo de Reparo do Mestre consegue reparar no momento. Se você acabou de masterizar uma nova especialização, recarregue a interface (/reload) para atualizar.",
    HIDE_IN_COMBAT                = "Ocultar em Combate",
    HIDE_IN_COMBAT_TOOLTIP        = "Oculta o addon enquanto você estiver em combate. A pré-visualização do Edit Mode ignora essa opção e sempre exibe.",
    CANNOT_REPAIR_TOOLTIP         = "Seu Martelo de Reparo do Mestre ainda não consegue reparar este item.",
    WARNING_ICON_SETTINGS         = "Configurações do Ícone de Aviso",

    TODAY_SAVED                   = "Economizado Hoje",
    TOTAL_SAVED                   = "Total Economizado",
    GOLD_SAVED_THIS_REPAIR        = "Você economizou %s neste reparo! Hoje: %s -- Total: %s",
    GOLD_RESET_CHAR_CONFIRM       = "Contador do personagem resetado. Total anterior arquivado: %s em %d reparos.",
    GOLD_RESET_ACCOUNT_CONFIRM    = "Contador da conta resetado. Total anterior arquivado: %s em %d reparos.",
    GOLD_RESET_TODAY_CHAR_CONFIRM    = "Contador de hoje do personagem resetado. Valor anterior arquivado: %s em %d reparos.",
    GOLD_RESET_TODAY_ACCOUNT_CONFIRM = "Contador de hoje da conta resetado. Valor anterior arquivado: %s em %d reparos.",
    GOLD_RESET_USAGE              = "Uso: /amrh reset char|account ou /amrh resettoday char|account",
    GOLD_SUMMARY_TODAY            = "Hoje: %s economizados em %d reparos.",
    GOLD_SUMMARY_TOTAL            = "No total: %s economizados em %d reparos.",
}
