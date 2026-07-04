# Plano de Features — Rodada 2026-07

Três features para o ArauMRHTool: (1) contador de gold economizado,
(2) indicador de "não posso reparar esse slot", (3) suporte a múltiplos hammers/expansões.
Toda a pesquisa de API necessária (Features 1, 2 e 3) foi validada in-game nesta rodada —
ver "Ordem de implementação sugerida" no fim pra status atualizado antes de começar a
codar.

Segue a arquitetura descrita em [GUIDELINES.md](../GUIDELINES.md) (namespace `ns`, config API,
i18n via `L`, refresh pipeline, checklist de feature).

---

## Decisões assumidas (confirmar antes de implementar)

Estas são escolhas que fiz para destravar o plano. Qualquer uma pode ser trocada.

1. **Contador de gold: por personagem *e* por conta**. `ArauMRHToolCharDB` (nova, per-
   character) guarda o total do personagem; `ArauMRHToolDB` (já existe, account-wide)
   ganha também um `goldSaved.total` próprio, incrementado junto sempre que o do
   personagem incrementa. O total da conta não é exibido em lugar nenhum por enquanto —
   só fica alimentado, pronto pra um uso futuro (ex. um segundo `Input readOnly` no
   painel, ou outro slash command).
2. **"Mensagem de sistema" = mensagem de chat normal** (tipo `print`, no chat frame
   padrão) — não `UIErrorsFrame`. A ideia é ficar registrado no histórico do chat, pra
   quem tava olhando outra coisa na hora do reparo (ex. no meio de uma dungeon) poder
   rolar a tela pra trás e ler depois.
3. ~~Botão no painel do Edit Mode~~ — **não precisa mais**. O reset do contador virou
   slash command (`/amrh reset char` / `/amrh reset account`, ver Feature 1), então não
   há mais necessidade de estender o LibEQOL com um `SettingType.Button` — o painel de
   settings fica só com o `Input readOnly` mostrando o total do personagem, sem tocar em
   lib de terceiros.

---

## Feature 1 — Gold economizado com o Master Repair Hammer

### Objetivo
Registrar quanto de gold foi economizado a cada uso do hammer (em vez de pagar reparo
num NPC), mostrar uma mensagem de sistema por reparo + total acumulado.

> Nota: a ideia original incluía um recurso de anúncio no chat (canal + mensagem
> customizável + botão de anunciar). Removida por hora a pedido do usuário — pode
> voltar numa rodada futura se fizer sentido.

### Como calcular o gold economizado (confirmado in-game)

`GetRepairAllCost()` e a tooltip legada (`GameTooltip:SetInventoryItem`) não servem —
a primeira só funciona com `MerchantFrame` aberto, e a segunda nem retorna mais
`repairCost` nesse client (confirmado: retorna só 1 valor). A API correta, validada
in-game (inclusive dentro de dungeon e em combate, sem vendor por perto), é a de
Tooltip Data moderna:

```lua
local data = C_TooltipInfo.GetInventoryItem("player", slotId)
local repairCost = data and data.repairCost -- copper; ausente/nil se o item está 100%
```

Isso dá o custo exato **por slot**, sempre disponível, sem depender de vendor. Resolve
o risco por completo — não precisamos de nenhuma estimativa por fórmula.

### Detecção do reparo
`iconFrame` é um `SecureActionButtonTemplate` com macro fixa (`/use item / use slotId`) —
não dá pra saber com certeza que o reparo *aconteceu* só pelo clique (pode falhar por
falta de charges, item já 100%, cooldown, etc.). Abordagem:

1. `HookScript("OnClick", ...)` no `iconFrame` (hook não-protegido, só leitura — não
   interfere no macro seguro): no clique, captura `repairCost` via
   `C_TooltipInfo.GetInventoryItem("player", slotId)` **antes** do reparo acontecer, e
   guarda `ns.pendingGoldSaved[slotId] = { repairCost = repairCost, previousCurrent = iconFrame.current }`
   (só se `repairCost` for um número > 0; senão não há nada a reparar, ignora). O
   `previousCurrent` é necessário pro passo 2 — sem ele não tem com o que comparar a
   durabilidade nova.
2. **No próximo** `UPDATE_INVENTORY_DURABILITY` (só esse — não fica esperando
   indefinidamente), para cada slot com entrada pendente: lê a durabilidade atual e
   compara com `previousCurrent`. Se aumentou, soma o `repairCost` guardado ao
   `goldSaved.total` e dispara a mensagem de sistema. Se não mudou, descarta sem contar.
   **Em ambos os casos, remove a entrada pendente logo em seguida** (não deixar
   "esperando" pra sempre) — senão um reparo pago num vendor horas depois (que também
   dispara `UPDATE_INVENTORY_DURABILITY`) seria creditado por engano como economia do
   hammer.

### Config nova

`ArauMRHToolCharDB` (nova, per-character):

| Path | Tipo | Default | Descrição |
|---|---|---|---|
| `goldSaved.total` | number (copper) | `0` | Total acumulado no personagem |
| `goldSaved.history` | table | `{}` | `[timestamp] = amountArquivado` — ver "Reset via slash command" |

`ArauMRHToolDB` (já existe, account-wide) ganha o mesmo par, incrementado junto:

| Path | Tipo | Default | Descrição |
|---|---|---|---|
| `goldSaved.total` | number (copper) | `0` | Total acumulado na conta inteira (soma de todos os personagens que usam o addon) |
| `goldSaved.history` | table | `{}` | Mesma lógica de arquivamento, independente do histórico por personagem |

Acesso ao per-character via novo par `ns:GetCharConfig(path, fallback)` /
`ns:SetCharConfig(path, value)` em `Core/Config.lua`, espelhando `GetConfig`/`SetConfig`
mas sobre `ArauMRHToolCharDB`. O account-wide usa o `ns:GetConfig`/`SetConfig` que já
existe (fora do namespace `editMode.layouts.*`, igual `debugEnabled`).

Toda vez que um reparo é confirmado (ver "Detecção do reparo"), soma o `repairCost` nos
**dois** totais (personagem e conta) — os dois avançam juntos, mas têm resets/históricos
independentes (dá pra resetar só o do personagem sem mexer no da conta, e vice-versa).

### Painel de settings (Edit Mode, LibEQOL)

Novo grupo **no topo** do array de `settings` em `AddFrameSettings()` (antes de
`durabilityThresholdConfig`) — só a exibição do total do personagem, sem botão (o reset
virou slash command, ver abaixo):

```
Collapsible "GOLD_SAVED_SETTINGS" (id = "goldSavedConfig")
  Input readOnly "TOTAL_SAVED"       -- exibe GetMoneyString(total, true), goldSaved.total do personagem
```

Não precisa de nenhum widget novo no LibEQOL — só o `Input` com `readOnly = true`, que já
existe (ver GUIDELINES.md).

### Reset via slash command

Trocado o botão no painel por dois slash commands — mais simples de implementar e não
"gasta" a UI do Edit Mode numa ação que é rara (reset não é algo que se faz toda hora):

```
/amrh reset char     -- arquiva e zera o total do personagem (ArauMRHToolCharDB)
/amrh reset account  -- arquiva e zera o total da conta (ArauMRHToolDB)
/amrh                -- (sem argumento válido) imprime uso no chat
```

**Arquivamento em vez de descarte**: em vez de simplesmente zerar, o valor atual do
total vai para `goldSaved.history[timestamp] = totalAtual` (chave = `time()`, o
timestamp do momento do reset) e só depois `goldSaved.total` volta a `0`. Nada se perde
— dá pra inspecionar `ArauMRHToolCharDB.goldSaved.history`/`ArauMRHToolDB.goldSaved.history`
depois pra ver quanto foi economizado em cada "era" entre resets.

Como nada é de fato perdido (só arquivado), não propus popup de confirmação — digitar o
comando específico já é uma ação deliberada o suficiente, e o custo de errar é baixo
(o valor "perdido" continua no `history`, só precisa somar de novo se quiser desfazer).
Depois do reset, imprime uma mensagem de chat confirmando (ex. "Contador do personagem
resetado. Total anterior arquivado: X").

Registrado em `Core/GoldTracking.lua` via `SLASH_ARAUMRHTOOL1 = "/amrh"` +
`SlashCmdList.ARAUMRHTOOL = function(msg) ... end`.

### Mensagem de chat por reparo
Ao detectar reparo bem-sucedido (ver "Detecção do reparo"), uma mensagem normal no chat
(fica no histórico, dá pra rolar pra trás depois):
```lua
print(("|cff00ff00[%s]|r %s"):format(addonName, L.GOLD_SAVED_THIS_REPAIR:format(amountStr, totalStr)))
```
com `L.GOLD_SAVED_THIS_REPAIR = "Você economizou %s neste reparo! Total: %s"`.

### Locale keys novas (enUS + ptBR)
`GOLD_SAVED_SETTINGS`, `TOTAL_SAVED`, `GOLD_SAVED_THIS_REPAIR`,
`GOLD_RESET_CHAR_CONFIRM`, `GOLD_RESET_ACCOUNT_CONFIRM`, `GOLD_RESET_USAGE`.

### Checklist (GUIDELINES)
- [ ] `## SavedVariablesPerCharacter: ArauMRHToolCharDB` no `.toc`
- [ ] `ns:GetCharConfig` / `ns:SetCharConfig` em `Core/Config.lua`
- [ ] `ns.defaults.goldSaved` (com `total` e `history`) em `ArauMRHTool.lua`
- [ ] Novo arquivo `Core/GoldTracking.lua` (hook de clique, cálculo, registro em char
      *e* account, slash command de reset com arquivamento)
- [ ] `SLASH_ARAUMRHTOOL1`/`SlashCmdList.ARAUMRHTOOL` em `Core/GoldTracking.lua`
- [ ] Setting novo em `AddFrameSettings()` (`EditMode.lua`) — só o `Input readOnly`
- [ ] Todas as strings via `L.<KEY>` nos dois locales

---

## Feature 2 — Indicador de "não posso reparar esse slot"

### Objetivo
Hoje mostramos todo equip com durabilidade baixa. Alguns desses slots o personagem não
consegue reparar com o MRH porque não "masterizou" a track daquele slot na especialização
de Blacksmith. Feature: (a) opção pra filtrar e mostrar só o que é reparável, (b) quando
mostrando tudo, um ícone de aviso (!) no ícone do slot não reparável, com tooltip.

### Risco técnico principal — API de especialização/perks

**Achados confirmados in-game:**

- A API real (client atual) é `C_ProfSpecs` — não usa `node`/`configID` cru direto como
  eu supunha inicialmente. Funções relevantes existentes:
  `GetConfigIDForSkillLine`, `SkillLineHasSpecialization`, `GetSpecTabIDsForSkillLine`,
  `GetSpecTabInfo`, `GetRootPathForTab`, `GetChildrenForPath`, `GetPerksForPath`,
  `GetStateForPath`, `GetStateForPerk`, `GetDescriptionForPath`, `GetDescriptionForPerk`,
  `GetEntryIDForPerk`. `C_Traits` (`GetTreeNodes`, `GetNodeInfo`, etc.) é a API de nível
  mais baixo por trás disso; provavelmente não precisamos mexer nela diretamente.
- **A tooltip do próprio hammer (`C_TooltipInfo.GetItemByID(238020)`) já revela regras
  importantes**, direto do jogo:
  ```
  Use: Repair a weapon or piece of plate armor you have specialized in repairing.
  Requires Midnight Blacksmithing (25)
  ```
  Duas mudanças de escopo em relação ao design original:
  1. **O hammer só repara armadura de Placa (Plate) e armas.** Um item de Malha/Couro/
     Tecido equipado num `WatchedSlot` nunca é reparável por ele, independente de
     especialização — é um filtro por subtipo do item (`armorSubclass`/`weaponSubclass`),
     adicional ao filtro por slot+especialização.
  2. **"Midnight Blacksmithing" é uma skill line separada da 164** (a base, usada hoje
     em `ns.const.Profession.BlacksmithSkillLineId` só pra detectar "é ferreiro"). Cada
     expansão tem sua própria skill line nomeada (Midnight Blacksmithing, Khaz Algar
     Blacksmithing, Dragon Isles Blacksmithing — nomes e IDs completos confirmados na
     Feature 3), com um ID próprio pra usar em `C_ProfSpecs.GetConfigIDForSkillLine(...)`
     (a 164 genérica não tem árvore de especialização própria). Isso vira o campo
     `specSkillLineId` em cada entry de `ns.const.RepairTracks` (Feature 3).

**Mapeamento confirmado (Midnight Blacksmithing, skill line 2907)** — obtido navegando
a árvore via `/run` em pequenos passos (`GetDefaultSpecSkillLine(164)` → 2907 →
`GetConfigIDForSkillLine`/`GetSpecTabIDsForSkillLine` → `GetTabInfo` (nome + `rootNodeID`)
→ `GetChildrenForPath` recursivo → `GetPerksForPath` por folha → `GetDescriptionForPerk`
pra achar o perk "Learn to craft a Thalassian Master Repair Hammer..."):

- `164` (skill line base) não tem árvore própria (`GetConfigIDForSkillLine(164)` = 0,
  `SkillLineHasSpecialization(164)` = false). O ID certo pra especialização da expansão
  atual vem de **`C_ProfSpecs.GetDefaultSpecSkillLine(164)`** → `2907` (Midnight
  Blacksmithing). `GetConfigIDForSkillLine(2907)` = `56994576`, `hasSpec` = `true`.
- Tab **Armorsmithing** = tabID `1075`, `rootNodeID` (= path ID raiz) `104576`.
  Tab **Weaponsmithing** = tabID `1076`, `rootNodeID` `104633` — cobre MainHand/OffHand-
  arma, mapeamento completo na seção "Weaponsmithing" logo abaixo.
- Os 3 branches da Armorsmithing e suas 3 folhas cada, com o **perk ID exato** que
  desbloqueia o repair (sempre o perk de maior índice retornado por
  `GetPerksForPath(pathID)` — o último dos 6 perks daquele path):

  | Slot | WatchedSlot | Path ID | Perk ID (repair) |
  |---|---|---|---|
  | Head | 1 | 104570 | 104519 |
  | Shoulder | 3 | 104569 | 104513 |
  | Chest | 5 | 104574 | 104544 |
  | Waist | 6 | 104566 | 104494 |
  | Legs | 7 | 104573 | 104538 |
  | Feet | 8 | 104568 | 104507 |
  | Wrist | 9 | 104565 | 104488 |
  | Hands | 10 | 104564 | 104482 |
  | OffHand (shield) | 17 | 104572 | 104532 |

Esses IDs são numéricos (independentes de locale) e viram o `requiredPerkBySlot` da
entry `midnight` em `ns.const.RepairTracks` (Feature 3).

**Checagem de "desbloqueado" (confirmado in-game):**
```lua
local state = C_ProfSpecs.GetStateForPerk(perkID, configID) -- precisa dos DOIS argumentos
local unlocked = (state == 2)
```
Testado com um perk que o usuário já tem masterizado (`state == 2`) e um que não tem
(`state == 0`). `ns:BuildRepairEligibilityCache()` guarda o `configID` da skill line uma
vez (via `GetConfigIDForSkillLine`) e testa cada `perkID` do track contra ele.

### Weaponsmithing (MainHand/OffHand-arma) — confirmado

Tab Weaponsmithing = tabID `1076`, `rootNodeID` `104633`. 3 branches:
- `104632` Edged weapons → `104631` Short blades, `104630` Long blades
- `104629` Hafted weapons → `104628` Maces, `104627` Axes/Polearms
- `104626` Whetstones/weightstones (consumíveis — **não concede repair**, ignorar)

Perk de repair de cada leaf (mesmo padrão: último perk de `GetPerksForPath`):

| Bucket | Path ID | Perk ID | `itemSubClassID` do peso (classID 2, confirmado in-game + correção do usuário) |
|---|---|---|---|
| Long blades | 104630 | 104601 | Sword 1H (7), Sword 2H (8), Warglaive (9) |
| Short blades | 104631 | 104607 | Dagger (15), Fist Weapon (13) |
| Maces | 104628 | 104589 | Mace 1H (4), Mace 2H (5) |
| Axes/Polearms | 104627 | 104583 | Axe 1H (0), Axe 2H (1), Polearm (6) |

Qualquer outro `itemSubClassID` de arma (arco, arma de fogo, cajado, varinha, besta,
arremesso, vara de pesca) nunca é reparável pelo MRH — Blacksmith não fabrica esses
tipos, então nem entra na checagem de especialização.

Pra armadura (`classID 4`), o `itemSubClassID` de Plate é `4`; Shields é sua própria
subclasse (`6`) mas já tem perk próprio (`104532`, ver tabela acima) — não faz parte do
filtro "precisa ser Plate", é tratado à parte. Qualquer outro subclass de armadura
(Cloth/Leather/Mail/Cosmético) nunca é reparável.

**Regra completa de elegibilidade por item** (`ns:CanRepairSlot`):
1. `classID == 4` (Armor): se `subclassID == 4` (Plate) → checa o perk do slot; se
   `subclassID == 6` (Shield, só em OffHand) → checa o perk de shields; qualquer outro
   subclass → nunca reparável.
2. `classID == 2` (Weapon, MainHand ou OffHand): resolve o bucket pelo `subclassID`
   (tabela acima) → checa o perk do bucket; subclass fora da tabela → nunca reparável.

### Helper
Este helper nasce já pensando na Feature 3 (multi-expansão) — ver seção 3 pra tabela de
tracks. Funções propostas (nome de arquivo definido na Feature 3):

```lua
ns:BuildRepairEligibilityCache() -- roda 1x no PLAYER_LOGIN, após HasBlacksmithing()
-- popula, por track (ver Feature 3):
--   ns.repairEligibility[trackKey].bySlot[slotId]          = bool  (armadura Plate + shields)
--   ns.repairEligibility[trackKey].byWeaponBucket[bucket]  = bool  (longBlades/shortBlades/maces/axesPolearms)

ns:BuildRepairPlan() -- roda logo em seguida (ver Feature 3): resolve, por slot/bucket,
                     -- a track mais nova masterizada, e guarda { maxItemLevelReq, hammerItemId }
                     -- em ns.repairPlan.bySlot[slotId] / ns.repairPlan.byWeaponBucket[bucket]

ns:CanRepairSlot(slotId, itemLevelReq, itemClassID, itemSubClassID) -- consulta ns.repairPlan
                                       -- (ver "Regra completa de elegibilidade por item"
                                       -- abaixo e "Macro por ícone" na Feature 3)
```

Cache/plano calculados 1x no login (a mastery da spec não muda em runtime, exceto respec
ao vivo — não vamos tentar detectar isso automaticamente). Quando o jogador masteriza uma
nova track, avisamos (texto estático no tooltip do ícone de aviso e/ou na tooltip do
checkbox de config) que precisa dar `/reload` pra atualizar.

### Config nova (layout-scoped, como as demais)

| Path | Tipo | Default | Descrição |
|---|---|---|---|
| `showOnlyRepairable` | boolean | `false` | Se `true`, `GetLowDurabilityItems` filtra slots não reparáveis |

### Mudanças em `EquipmentFrame.lua`
- `GetLowDurabilityItems()`: se `showOnlyRepairable` = true, pular slots onde
  `ns:CanRepairSlot(slotId, itemLevelReq, classID, subclassID)` é `false` (ver "Regra
  completa de elegibilidade por item" acima).
- Novo overlay de aviso: textura extra no `iconFrame` (`iconFrame.warningIcon`), criada
  em `CreateEquipmentIconFrame`, ancorada `TOPRIGHT` do ícone, textura
  `Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew` (ou
  `Interface\\GossipFrame\\DailyQuestIcon` como alternativa — validar visual em jogo).
  Mostrado apenas quando `showOnlyRepairable == false` **e** `not ns:CanRepairSlot(...)`.
- Tooltip do warning icon: `OnEnter`/`OnLeave` próprios (`GameTooltip:SetText(L.CANNOT_REPAIR_TOOLTIP)`),
  separados da tooltip do item (que já mostra o item em si).
- `GetDummyItems()`: como não há personagem real, aleatorizar com no mínimo 1 e no máximo 3, para visualizar o ícone de aviso no preview — melhor pra testar o layout no Edit Mode).

### Locale keys novas
`SHOW_ONLY_REPAIRABLE` (nome do checkbox), `SHOW_ONLY_REPAIRABLE_TOOLTIP` (menciona o
`/reload` após masterizar nova track), `CANNOT_REPAIR_TOOLTIP`.

### Checklist (GUIDELINES)
- [ ] `ns.defaults.showOnlyRepairable = false`
- [ ] Checkbox em `AddFrameSettings()` (grupo `iconConfigs` ou novo grupo)
- [ ] Novo `iconFrame.warningIcon` em `CreateEquipmentIconFrame` + `LayoutIcon`/`ResetIcon`
- [ ] `GetLowDurabilityItems` e `GetDummyItems` respeitam o filtro
- [ ] Locale keys nos dois idiomas

---

## Feature 3 — Suporte a múltiplos Master Repair Hammers por expansão

### Objetivo
O MRH correto depende do nível requerido do item. Existem hoje **3 hammers**, não 2
como imaginado inicialmente:

| Track | Hammer | Item ID | Skill line | Teto de req. level |
|---|---|---|---|---|
| Dragon Isles | Master's Hammer | `201366` | Dragon Isles Blacksmithing (`2822`) | ≤ 70 |
| Khaz Algar (The War Within) | Earthen Master's Hammer | `225660` | Khaz Algar Blacksmithing (`2872`) | ≤ 80 |
| Midnight | Thalassian Master Repair Hammer | `238020` | Midnight Blacksmithing (`2907`) | ≤ 90 |

### Achado importante: cobertura por teto, não por faixa exclusiva

Diferente do que supus inicialmente (faixas fechadas tipo "81–90" / "71–80"), **cada
hammer repara qualquer item com req. level até o seu teto** — as faixas se sobrepõem.
Um item de req. level 65, por exemplo, está dentro do teto dos 3 hammers ao mesmo tempo.

O que decide se dá pra reparar não é "qual faixa bate com esse nível", e sim, pra
**cada track cujo teto cobre o item**: esse hammer específico foi masterizado pro
slot/tipo de arma daquele item **na árvore de especialização daquela track** (cada
track tem seu próprio `configID`/árvore, independente das outras — masterizar "reparar
peito" no Midnight não implica ter masterizado o mesmo em Khaz Algar ou Dragon Isles).

Isso significa que resolver "qual hammer serve" não é mais "olha a faixa do nível e pega
a track única correspondente" — é "entre as tracks cujo teto cobre o item, qual delas
tem a especialização masterizada". A boa notícia é que essa pergunta só depende da
especialização (fixa até o próximo `/reload`), não do item em si — então dá pra
responder **uma vez por slot/bucket, no login**, em vez de a cada refresh. Ver
"Simplificação: plano de reparo pré-computado no login" logo abaixo.

### Arquivo novo: `Core/RepairTracks.lua`
Carregado logo após `Core/Enum.lua` no `.toc` (antes de `ArauMRHTool.lua`, já que
`ArauMRHTool.lua` pode querer referenciar os tracks nos defaults/const — a ordem exata
será ajustada na implementação).

```lua
ns.const.RepairTracks = {
    {
        key = "midnight",
        maxItemLevelReq = 90,
        hammerItemId = 238020, -- Thalassian Master Repair Hammer
        specSkillLineId = 2907, -- Midnight Blacksmithing (configID confirmado: 56994576)
        requiredPerkBySlot = {
            [1] = 104519,  -- Head
            [3] = 104513,  -- Shoulder
            [5] = 104544,  -- Chest
            [6] = 104494,  -- Waist
            [7] = 104538,  -- Legs
            [8] = 104507,  -- Feet
            [9] = 104488,  -- Wrist
            [10] = 104482, -- Hands
            [17] = 104532, -- OffHand (shield)
        },
        requiredPerkByWeaponBucket = {
            longBlades = 104601,   -- Sword 1H(7)/2H(8), Warglaive(9)
            shortBlades = 104607,  -- Dagger(15), Fist Weapon(13)
            maces = 104589,        -- Mace 1H(4)/2H(5)
            axesPolearms = 104583, -- Axe 1H(0)/2H(1), Polearm(6)
        },
    },
    {
        key = "khazAlgar", -- The War Within
        maxItemLevelReq = 80,
        hammerItemId = 225660, -- Earthen Master's Hammer
        specSkillLineId = 2872, -- Khaz Algar Blacksmithing (configID confirmado: 46377247)
        requiredPerkBySlot = {
            [1] = 99182,  -- Head
            [3] = 99176,  -- Shoulder
            [5] = 99207,  -- Chest
            [6] = 99157,  -- Waist
            [7] = 99201,  -- Legs
            [8] = 99170,  -- Feet
            [9] = 99151,  -- Wrist
            [10] = 99145, -- Hands
            [17] = 99195, -- OffHand (shield)
        },
        requiredPerkByWeaponBucket = {
            longBlades = 99422,   -- Sword 1H(7)/2H(8), Warglaive(9)
            shortBlades = 99428,  -- Dagger(15), Fist Weapon(13)
            maces = 99410,        -- Mace 1H(4)/2H(5)
            axesPolearms = 99404, -- Axe 1H(0)/2H(1), Polearm(6)
        },
    },
    {
        key = "dragonIsles",
        maxItemLevelReq = 70,
        hammerItemId = 201366, -- Master's Hammer
        specSkillLineId = 2822, -- Dragon Isles Blacksmithing (configID confirmado: 46377245)
        requiredPerkBySlot = {
            [1] = 23851,  -- Head
            [3] = 23844,  -- Shoulder
            [5] = 23879,  -- Chest
            [6] = 23823,  -- Waist
            [7] = 23872,  -- Legs
            [8] = 23837,  -- Feet
            [9] = 23816,  -- Wrist
            [10] = 23809, -- Hands
            [17] = 23865, -- OffHand (shield)
        },
        requiredPerkByWeaponBucket = {
            longBlades = 23693,   -- Sword 1H(7)/2H(8), Warglaive(9)
            shortBlades = 23700,  -- Dagger(15), Fist Weapon(13)
            maces = 23679,        -- Mace 1H(4)/2H(5)
            axesPolearms = 23672, -- Axe 1H(0)/2H(1), Polearm(6)
        },
    },
}
```

Toda a lógica de "quais tracks servem pra esse item" e "qual hammer usar" fica isolada
aqui, então um level pruning futuro é só editar essa tabela (sem tocar em
`EquipmentFrame.lua`).

### Simplificação: plano de reparo pré-computado no login

Proposta do usuário, boa simplificação: em vez de resolver "qual track/hammer serve" a
cada refresh (chamando `GetStateForPerk` toda hora), pré-computar isso **uma vez no
login**, junto com `ns:BuildRepairEligibilityCache()`.

**Achado que viabiliza isso**: rodar o macro do hammer num item que ele não repara
(Couro/Malha/Tecido, ou slot sem especialização) **não dá erro Lua nem quebra nada** —
o próprio jogo só mostra uma mensagem na tela e não faz nada (confirmado pelo usuário).
Ou seja, não tem problema o macro de um ícone "errar o alvo" — o pior caso é o clique
não fazer nada, igual clicar um botão apontando pro slot errado.

`ns.const.RepairTracks` já está ordenado da mais nova pra mais antiga (midnight →
khazAlgar → dragonIsles) — **essa ordem passa a importar**: ao montar o plano, iteramos
nessa ordem e pegamos a **primeira** track (a mais nova possível) cujo perk daquele
slot/bucket está masterizado. Como uma track mais nova sempre cobre um teto de nível maior
que as mais antigas, a primeira track masterizada já é a melhor opção — não precisa
comparar as outras.

```lua
ns:BuildRepairPlan() -- roda no login, logo após ns:BuildRepairEligibilityCache()
-- para cada WatchedSlot puro de armadura (Head/Shoulder/Chest/Waist/Legs/Feet/Wrist/Hands)
-- e para cada weapon bucket (longBlades/shortBlades/maces/axesPolearms) e pro shield (slot 17):
--   percorre ns.const.RepairTracks (midnight -> khazAlgar -> dragonIsles)
--   pega a 1ª track cujo requiredPerkBySlot[slot] (ou requiredPerkByWeaponBucket[bucket])
--   está com state == 2 nessa track (usa o cache de eligibility já calculado)
--   guarda em ns.repairPlan.bySlot[slotId] / ns.repairPlan.byWeaponBucket[bucket]:
--     { maxItemLevelReq = track.maxItemLevelReq, hammerItemId = track.hammerItemId }
--   (nil se nenhuma track tiver aquele slot/bucket masterizado — nunca reparável)
```

### Macro por ícone — dois casos diferentes

**Os 8 slots puros de armadura** (Head/Shoulder/Chest/Waist/Legs/Feet/Wrist/Hands): a
"categoria" do slot nunca muda em runtime (Chest é sempre peça de peito, seja ela Placa,
Malha, Couro ou Tecido) — o macro pode ser escrito **uma única vez**, logo depois que
`ns:BuildRepairPlan()` roda no login (ex. dentro de `CreateAddonFrame`/`CreateEquipmentIconFrame`,
não em `LayoutIcon`), e nunca mais mexido durante a sessão:
```lua
local plan = ns.repairPlan.bySlot[slotId]
if plan then
    iconFrame:SetAttribute("macrotext", "/use item:" .. plan.hammerItemId .. "\r\n/use " .. slotId)
end
-- se plan for nil (nenhuma track masterizada pra esse slot), simplesmente não seta —
-- o botão fica sem macro (clique não faz nada), e como o achado acima confirma que
-- isso é inofensivo mesmo quando o item mudar depois, não precisa reavaliar.
```

**MainHand e OffHand são ambíguos** — o item equipado pode ser qualquer bucket de arma
(MainHand/OffHand) ou um shield (só OffHand), e isso *varia* conforme o que tá equipado.
Esses dois continuam precisando de uma decisão em `LayoutIcon`/refresh, mas agora é só
uma **consulta ao plano pré-computado** (rápida, sem chamar `C_ProfSpecs` de novo):
```lua
local plan
if itemData.classID == 4 and itemData.subclassID == 6 then -- Shield
    plan = ns.repairPlan.bySlot[17]
elseif itemData.classID == 2 then -- Weapon
    local bucket = ns:GetWeaponBucket(itemData.subclassID) -- Feature 2
    plan = bucket and ns.repairPlan.byWeaponBucket[bucket]
end

if plan then
    iconFrame:SetAttribute("macrotext", "/use item:" .. plan.hammerItemId .. "\r\n/use " .. slotId)
end
-- não precisa de `else` limpando o macro: um macro "desatualizado" de uma arma anterior
-- só falharia silenciosamente (mensagem na tela) se o novo item não bater com aquele
-- hammer/bucket — inofensivo, confirmado acima. Ainda assim, dá pra limpar por
-- higiene/clareza de debug, sem que seja uma correção de bug.
```
Isso roda dentro do guard de `InCombatLockdown()` existente em `RefreshFrame` (mudar
atributo de frame seguro em combate também é restrito) — só precisa desse guard pra
MainHand/OffHand, já que os outros 8 slots nem tocam o macro fora do login.

**Elegibilidade (`showOnlyRepairable`/ícone de aviso)** também fica mais simples: com o
plano pré-computado, é só comparar `itemData.itemLevelReq <= plan.maxItemLevelReq` (e
`plan` não ser `nil`) — nenhuma chamada de API viva por refresh, só leitura de tabela.

Consequência: `GetLowDurabilityItems`/`GetDummyItems` precisam passar a incluir
`itemLevelReq`, `classID` e `subclassID` no `itemData` de cada slot (hoje só tem
`slotId, texture, current, maximum, ratio`) — via `GetInventoryItemLink` + `GetItemInfo`
(`classID`/`subclassID` são o 12º/13º retorno; `itemLevelReq` = 5º retorno, `minLevel`).

### Nota de atenção — track sem especialização
No personagem de teste, as 3 skill lines (`2822`, `2872`, `2907`) retornaram `hasSpec:
true`. Mas um Blacksmith que nunca tocou conteúdo de uma expansão anterior pode ter
`GetConfigIDForSkillLine(track.specSkillLineId)` retornando `0`/inválido pra aquela
track específica (igual aconteceu com a skill line base `164`). `ns:BuildRepairEligibilityCache()`
precisa tratar isso sem erro: track com `configID` inválido = track inteira indisponível
pra esse personagem (todos os slots/buckets dela ficam `false`, `ns:BuildRepairPlan()`
simplesmente pula essa track na busca pela "mais nova masterizada").

### Riscos / perguntas em aberto — todos resolvidos

~~Mapeamento `requiredPerkBySlot`/`requiredPerkByWeaponBucket` por track~~ — **resolvido
para as 3 tracks** (Midnight, Khaz Algar, Dragon Isles), todas com a mesma estrutura
(Armorsmithing: 3 branches x 3 slots cada; Weaponsmithing: short/long blades, maces,
axes/polearms). IDs completos na tabela `ns.const.RepairTracks` acima.

~~Qual API dá o "req level" do item~~ — **confirmado**: é `minLevel` (5º retorno de
`GetItemInfo`), testado com dois itens reais (`Relentless Rider's Crown`, item Midnight:
`minLevel 90`; `Explorer's Expert Helm`, item Dragonflight: `minLevel 70`) — bate
exatamente com os tetos das 3 tracks, o que também confirma a hipótese de que os tetos
(70/80/90) são os level caps de personagem de cada expansão.

Item fora do teto de qualquer track (ex. algum req level que nenhum hammer cubra): trata
como "não reparável", igual Feature 2 já cobre (`showOnlyRepairable`/ícone de aviso) —
não é bem um risco, só o caminho natural do design.

**Nota lateral não bloqueante**: Dragon Isles tem uma 4ª aba na especialização chamada
"Hammer Control" (tabID `469`) que Midnight e Khaz Algar não têm. Não foi necessária pro
mapeamento (achamos os perks de repair sem ela), mas vale conferir na implementação caso
algo não bata na prática.

Com isso, a Feature 3 (e a parte de elegibilidade da Feature 2) está com todo o
levantamento de API/dados concluído — pronta pra implementar.

### Checklist (GUIDELINES)
- [ ] Novo arquivo `Core/RepairTracks.lua`, registrado no `.toc`
- [ ] `ns.const.RepairTracks` com as 3 entries (Dragon Isles / Khaz Algar / Midnight),
      ordem importa (mais nova primeiro)
- [ ] `itemData.itemLevelReq`, `classID`, `subclassID` adicionados em
      `GetLowDurabilityItems`/`GetDummyItems`
- [ ] `ns:BuildRepairPlan()` (login, após `BuildRepairEligibilityCache`)
- [ ] Macro dos 8 slots de armadura escrito uma vez (login/criação do frame), não em
      `LayoutIcon`
- [ ] Macro de MainHand/OffHand recalculado em `LayoutIcon` (dentro do guard de combate
      existente), via consulta a `ns.repairPlan` (sem chamada viva de `C_ProfSpecs`)
- [ ] `ns:CanRepairSlot` (Feature 2) atualizado pra consultar `ns.repairPlan`

---

## Ordem de implementação sugerida

1. **Feature 3 primeiro (fundação de dados)**: criar `Core/RepairTracks.lua`,
   `ns:BuildRepairPlan()` e o suporte a `itemLevelReq`/`classID`/`subclassID` no
   `itemData`. Evita implementar a Feature 2 assumindo um único hammer e depois ter que
   reescrever.
2. **Feature 2 em cima da fundação**: cache de eligibility, checkbox de filtro, ícone
   de aviso — usando `ns.repairPlan` já pronto.
3. **Feature 1 por último ou em paralelo**: é independente das outras duas (só depende
   do clique no botão de reparo, não de qual hammer foi usado).

Toda a pesquisa de API foi concluída nesta rodada (ver seções de cada feature) — não há
mais pendência de investigação in-game bloqueando o início da implementação. Ponto que
ficou como nota de atenção pra hora de codar (não bloqueia o início, mas merece atenção):
- Tracks cujo `configID` vier `0`/`hasSpec=false` pro personagem (Feature 3) — ver nota
  de tratamento defensivo na seção da Feature 3.
