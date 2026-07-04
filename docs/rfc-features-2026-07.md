# RFC — Gold Economizado, Indicador de Elegibilidade de Reparo e Suporte Multi-Expansão

- **Status**: Implementado
- **Data**: 2026-07-04
- **Referências**: [ADR](./adr-features-2026-07.md) · [Plano de trabalho / histórico de investigação](./plano-features-2026-07.md)

## Resumo

Três features pro ArauMRHTool:

1. **Gold economizado** — rastreia quanto foi poupado usando o Master Repair Hammer em
   vez de pagar reparo num NPC (total + diário, por personagem + por conta), com
   feedback no chat e slash commands de reset/resumo.
2. **Indicador de elegibilidade de reparo** — filtro opcional + ícone de aviso pra
   slots que o hammer não consegue reparar (falta de especialização, ou o item não é
   nem Placa nem arma).
3. **Suporte multi-expansão** — o MRH na verdade é 3 hammers diferentes (um por
   expansão), cada um com sua própria árvore de especialização e teto de nível; o
   addon precisa saber usar o certo pra cada peça de equipamento.

## Motivação

- Dar ao jogador uma noção concreta de quanto o addon (e o hammer) já economizou em
  reparo — hoje isso não é visível em lugar nenhum.
- O addon mostrava **todo** equipamento danificado, mesmo quando o personagem não tinha
  especialização suficiente pra realmente repará-lo com o hammer — gerando cliques que
  não faziam nada, sem nenhum aviso.
- O MRH não é um item único: existem 3 hammers (Dragon Isles, The War Within/Khaz
  Algar, Midnight), cada um com sua própria árvore de especialização e teto de nível.
  O addon só suportava 1 (hardcoded), quebrando pra quem ainda repara itens de
  expansões anteriores.

---

## Feature 1 — Gold economizado

### Cálculo do valor economizado

`C_TooltipInfo.GetInventoryItem(unit, slotId).repairCost` dá o custo exato de reparo
por slot, disponível em qualquer lugar do mundo (validado em dungeon e em combate, sem
depender de estar perto de um vendor).

### Detecção do reparo

O botão de reparo é um `SecureActionButtonTemplate` com macro segura — não existe um
evento nativo "hammer usado com sucesso". Abordagem:

1. Hook de clique (`HookScript OnClick`, não-protegido) captura `repairCost` e a
   durabilidade atual do slot **antes** do reparo — mas só se o slot for realmente
   reparável pelo MRH naquele momento (`iconFrame.repairable`, calculado no último
   refresh). Cliques em slots não-reparáveis não geram nenhum registro.
2. No **próximo** `UPDATE_INVENTORY_DURABILITY`, compara a durabilidade nova com a
   guardada; se aumentou, credita a economia. Em qualquer caso (creditou ou não), a
   entrada pendente é descartada nesse mesmo evento — não fica esperando indefinidamente.

### Dados rastreados

Por personagem (`ArauMRHToolCharDB`) e por conta (`ArauMRHToolDB`), em paralelo:

- `goldSaved.total` / `goldSaved.daily["yyyymmdd"]`
- `repairCount.total` / `repairCount.daily["yyyymmdd"]`
- `goldSaved.history` / `goldSaved.dailyHistory` / `repairCount.history` /
  `repairCount.dailyHistory` — arquivo de valores anteriores a resets, chave = timestamp
  do momento do reset.

### Interação

- Mensagem de chat a cada reparo confirmado: valor economizado + total de hoje + total
  geral.
- Painel de Edit Mode: `Today's Saved` e `Total Saved` (nessa ordem), como `Input`
  somente-leitura, sem estarem dentro de um grupo colapsável.
- Slash commands:
  - `/amrh` (sem argumento) — resumo: quanto foi economizado hoje e no total, com a
    quantidade de reparos de cada um.
  - `/amrh reset char|account` — arquiva e zera o total (ouro + contagem de reparos).
  - `/amrh resettoday char|account` — arquiva e zera só o dia atual (ouro + contagem).

---

## Feature 2 — Indicador de elegibilidade de reparo

### Config

Checkbox `showOnlyRepairable` (layout-scoped, igual as demais configs visuais): quando
ativo, `GetLowDurabilityItems`/`GetDummyItems` só retornam slots que o MRH consegue
reparar de fato.

### Indicação visual (quando o filtro está desligado)

- Ícone principal do slot fica dessaturado (`Texture:SetDesaturated`).
- Ícone de aviso (triângulo de alerta, com contorno preto de 2px) no canto superior
  direito, com tooltip própria explicando o motivo. Tamanho e offset X/Y configuráveis
  no Edit Mode (mesmo padrão do texto de durabilidade).

### Regra de elegibilidade

`ns:CanRepairSlot(slotId, itemLevelReq, classID, subclassID)`:

1. Armadura (`classID` = Armor): `subclassID` = Plate → checa o perk daquele slot
   específico; `subclassID` = Shield (só possível em OffHand) → checa o perk de
   shields. Qualquer outro subtipo de armadura nunca é reparável.
2. Arma (`classID` = Weapon): resolve o bucket (long blades / short blades / maces /
   axes-polearms) pelo `subclassID` e checa o perk daquele bucket. Subtipo de arma fora
   dessas categorias nunca é reparável (o Blacksmith não fabrica esses tipos).

A consulta em si é uma leitura de tabela pré-computada (ver Feature 3), não uma
chamada viva de API por refresh.

---

## Feature 3 — Suporte multi-expansão

### Dados (`Core/RepairTracks.lua`)

Três tracks, cada uma com hammer, skill line de especialização, e os IDs de
perk/path necessários pra reparar cada slot de armadura e cada bucket de arma:

| Track | Hammer | Item ID | Teto de req. level |
|---|---|---|---|
| Dragon Isles | Master's Hammer | 201366 | ≤ 70 |
| Khaz Algar (The War Within) | Earthen Master's Hammer | 225660 | ≤ 80 |
| Midnight | Thalassian Master Repair Hammer | 238020 | ≤ 90 |

(Tabela completa de perk/path IDs por slot/bucket e por track: ver `RepairTracks.lua`
ou o histórico de investigação no plano de trabalho.)

### Cobertura por teto, não faixa exclusiva

Cada hammer repara qualquer item com req. level até o seu teto — as faixas se
sobrepõem. O que decide se dá pra reparar não é "que faixa bate com esse nível", é
"entre as tracks cujo teto cobre o item, qual delas tem a especialização masterizada".

### Plano de reparo pré-computado

No login, depois de `HasBlacksmithing()`:

1. `BuildRepairEligibilityCache()` — consulta `C_ProfSpecs` uma vez por track, guarda
   se cada perk (slot/bucket) está desbloqueado.
2. `BuildRepairPlan()` — resolve, por slot de armadura e por bucket de arma, a track
   mais nova (dentre as masterizadas) e guarda `{ maxItemLevelReq, hammerItemId }`.

A partir daí, elegibilidade e escolha de hammer viram leitura direta desse plano, sem
chamada de API por refresh.

### Macro do botão de reparo

- **8 slots puros de armadura** (Head/Shoulder/Chest/Waist/Legs/Feet/Wrist/Hands): a
  categoria do slot nunca muda em runtime — o macro é escrito **uma vez**, no login, e
  nunca mais tocado.
- **MainHand/OffHand**: a categoria (bucket de arma, ou shield no caso do OffHand)
  varia com o item equipado — o macro é recalculado a cada refresh, consultando o
  plano pré-computado (leitura de tabela, sem chamada viva de API).

Rodar o macro do hammer num item que ele não repara é inofensivo (confirmado in-game:
o jogo só mostra uma mensagem, sem erro Lua) — por isso não é necessário limpar o
macro quando um item deixa de ser reparável.

---

## Riscos e limitações conhecidas

- Os IDs de perk/path de cada track são hardcoded, obtidos por investigação manual
  in-game (não há documentação oficial da API pra isso). Uma reestruturação da árvore
  de especialização ou um level pruning futuro exigiria remapear manualmente.
- `C_Item.GetItemInfo`/`GetInventoryItemDurability` podem retornar `nil` se os dados
  ainda não foram sincronizados pelo cliente (mais comum logo após um login "frio").
  Mitigado por um retry adaptativo no login (ver ADR).
- Sem popup de confirmação nos resets — o design de "arquivar antes de zerar" já cobre
  o caso de erro do usuário.

## Fora de escopo (descartado nesta rodada)

- Anúncio do total economizado num canal de chat escolhido pelo usuário (ideia
  original da Feature 1) — removido a pedido do usuário; pode voltar numa rodada
  futura.
