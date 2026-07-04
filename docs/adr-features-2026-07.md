# ADR — Decisões da Rodada de Features 2026-07

- **Status**: Aceito / implementado
- **Data**: 2026-07-04
- **Referências**: [RFC](./rfc-features-2026-07.md) · [Plano de trabalho / histórico de investigação](./plano-features-2026-07.md)

Cada entrada segue Contexto → Decisão → Consequências. Numeração é só ordem de
registro, não prioridade.

---

## 1. Mensagem de reparo no chat normal, não `UIErrorsFrame`

**Contexto**: precisávamos avisar o jogador de quanto foi economizado a cada reparo.
A primeira ideia foi `UIErrorsFrame:AddMessage` (texto que aparece no topo-centro e
some sozinho).

**Decisão**: usar uma mensagem de chat normal (`print` com prefixo colorido), não
`UIErrorsFrame`.

**Consequências**: fica registrada no histórico de chat, dá pra rolar pra trás depois
(útil se o jogador tava olhando outra coisa, ex. no meio de uma dungeon). É a única
peça do design de gold que não foi "validada em jogo" com uma API específica — é só
`print`, comportamento já conhecido e estável.

---

## 2. Reset do contador via slash command, não botão no Edit Mode

**Contexto**: o painel de settings do LibEQOL não tem um widget de botão nativo (só
Checkbox/Dropdown/MultiDropdown/Slider/Color/Input/Divider/Collapsible). Cogitamos
estender a lib vendorizada (`Libs/LibEQOL`, fora do controle de versão do projeto) com
um novo `SettingType.Button`.

**Decisão**: não mexer na lib de terceiros — o reset virou slash command
(`/amrh reset char|account`, depois `/amrh resettoday char|account`).

**Consequências**: painel de Edit Mode fica só com displays somente-leitura
(`Today's Saved`/`Total Saved`); nenhuma modificação em código de terceiros; reset é
uma ação mais "deliberada" (precisa digitar o comando certo).

---

## 3. Arquivamento em vez de descarte no reset

**Contexto**: resetar o contador não deveria simplesmente destruir o dado.

**Decisão**: todo reset move o valor atual pra uma entrada de histórico
(`goldSaved.history`/`goldSaved.dailyHistory`, e depois também
`repairCount.history`/`repairCount.dailyHistory`), chave = timestamp do momento do
reset (`time()`), e só então zera o valor corrente.

**Consequências**: nada se perde — dá pra inspecionar quanto foi economizado em cada
"era" entre resets. Por causa disso, não tem popup de confirmação antes do reset: o
custo de errar é baixo (o valor "perdido" continua arquivado).

---

## 4. Detecção de reparo: hook de clique + comparação one-shot de durabilidade

**Contexto**: o botão de reparo é um `SecureActionButtonTemplate` com macro segura —
não existe evento nativo "hammer usado com sucesso"; só dá pra inferir observando a
durabilidade mudar depois do clique.

**Decisão**: hook não-protegido no clique (`HookScript`, não `SetScript` — não
interfere na macro segura) captura `repairCost` e a durabilidade atual **só se o slot
for reparável** (`iconFrame.repairable`, do último refresh). No próximo
`UPDATE_INVENTORY_DURABILITY`, compara e credita se a durabilidade subiu — e a entrada
pendente é **sempre** descartada nesse evento, seja creditada ou não (não fica
esperando indefinidamente por um evento futuro).

**Consequências**: corrige dois bugs encontrados em teste real:
- Sem a checagem de "one-shot" (sempre descartar no próximo evento), um reparo pago
  no vendor horas depois de um clique fracassado seria creditado por engano como
  economia do hammer.
- Sem a checagem `iconFrame.repairable` antes de registrar a entrada pendente, um
  clique num slot que o MRH não repara (ex. MainHand sem especialização) ainda gerava
  uma entrada esperando qualquer aumento de durabilidade futuro — inclusive um reparo
  pago no vendor logo em seguida, que foi exatamente o cenário reproduzido em teste.

---

## 5. `RepairTracks.lua` concentra dado + lógica (exceção à convenção de constantes)

**Contexto**: o GUIDELINES.md do projeto recomenda colocar novas constantes em
`ArauMRHTool.lua` junto com as demais. A tabela de tracks (`ns.const.RepairTracks`) é
grande (~90 linhas) e só é lida pelas próprias funções do módulo de elegibilidade.

**Decisão**: manter a const table e toda a lógica que a consome
(`BuildRepairEligibilityCache`, `BuildRepairPlan`, `GetRepairPlanEntry`,
`CanRepairSlot`, `GetWeaponBucket`) no mesmo arquivo novo (`Core/RepairTracks.lua`),
em vez de separar dado (em `ArauMRHTool.lua`) de lógica (em outro arquivo).

**Consequências**: exceção documentada à convenção padrão do projeto — justificada
porque nenhum outro arquivo referencia `ns.const.RepairTracks` diretamente, então
manter tudo junto favorece coesão sobre a convenção genérica.

---

## 6. Plano de reparo pré-computado no login (não resolvido a cada refresh)

**Contexto**: resolver "qual hammer serve pra esse item" exigiria checar
`C_ProfSpecs.GetStateForPerk` a cada refresh — potencialmente repetido a cada
mudança de equipamento/durabilidade.

**Decisão**: computar uma vez, no login (`BuildRepairPlan`, logo após
`BuildRepairEligibilityCache`), guardando por slot de armadura e por bucket de arma
qual é a track mais nova mastigada e o `hammerItemId` correspondente.

**Consequências**: refresh vira leitura de tabela (`ns.repairPlan`), sem chamada de
API repetida. Trade-off aceito: se o jogador masteriza uma nova track no meio da
sessão, precisa dar `/reload` pra atualizar (avisado no tooltip do checkbox de
filtro).

---

## 7. Macro dos 8 slots de armadura fixado no login; MainHand/OffHand por refresh

**Contexto**: inicialmente cogitamos limpar o macro (`SetAttribute("macrotext", "")`)
sempre que um item deixasse de ser reparável, como proteção defensiva.

**Decisão** (revista após teste do usuário): confirmado in-game que rodar o macro do
hammer num item que ele não repara é inofensivo — o jogo só mostra uma mensagem, sem
erro Lua. Com isso: os 8 slots de armadura (categoria fixa — sempre a mesma peça de
equipamento) têm o macro escrito **uma vez**, na criação do ícone; só MainHand/OffHand
(categoria variável conforme o item equipado) recalculam o macro a cada refresh.

**Consequências**: menos trabalho por refresh (nenhuma chamada de API pros 8 slots
fixos depois do login); não precisa de lógica de "limpar macro" quando um item deixa
de ser reparável — vira só uma questão de higiene opcional, não correção de bug.

---

## 8. Cobertura por teto, não faixa exclusiva, entre as tracks

**Contexto**: a suposição inicial era que cada track cobria uma faixa exclusiva de
nível (ex. "req level 81–90 = Midnight, 71–80 = TWW").

**Decisão** (revista após achado in-game): cada hammer repara qualquer item com req.
level até o seu teto — Midnight (≤90) cobre tudo que TWW (≤80) e Dragon Isles (≤70)
cobririam. O que decide se dá pra reparar é a especialização de cada track
especificamente, não o nível do item sozinho.

**Consequências**: `ns.const.RepairTracks` usa só `maxItemLevelReq` (teto), sem
`minItemLevelReq`. A ordem do array (mais nova pra mais antiga) passa a ser
significativa — `BuildRepairPlan` depende dela pra escolher a track "vencedora" por
slot/bucket.

---

## 9. Frame sumido no login: retry adaptativo, não evento único

**Contexto**: bug reportado em teste — o addon não aparecia num connect novo (embora
aparecesse após `/reload` ou ao entrar no Edit Mode). Logs de debug confirmaram:
`GetInventoryItemDurability` retorna `nil` pra tudo bem no `PLAYER_LOGIN` de um connect
novo (dado ainda não sincronizado pelo cliente). Nem `UPDATE_INVENTORY_DURABILITY`
(só dispara em *mudança*, não em sincronização inicial) nem `PLAYER_ENTERING_WORLD`
resolveram — confirmado experimentalmente, aguardando mais de um minuto sem o evento
disparar.

**Decisão**: retry com intervalo fixo (a cada 3s, até 8 tentativas — ~24s no pior
caso) que para assim que `GetInventoryItemDurability` deixa de retornar `nil` pra
qualquer slot monitorado, em vez de confiar num evento específico ou num número fixo
de tentativas sem verificação.

**Consequências**: robusto a conexões/PCs lentos sem desperdiçar tentativas quando os
dados chegam rápido (para assim que confirma sincronização, geralmente já na 1ª ou 2ª
tentativa). Não existe, aparentemente, um evento nativo confiável para "dado inicial
disponível" nesse cliente — só para mudança.

---

## 10. Mapeamento de perk/track IDs via investigação manual in-game

**Contexto**: não há documentação oficial da API `C_ProfSpecs` para Blacksmithing;
precisávamos descobrir, por track (Dragon Isles/Khaz Algar/Midnight), quais
path/perk IDs correspondem a cada slot de armadura e bucket de arma.

**Decisão**: navegação manual via `/run`, em passos pequenos por causa do limite de
255 caracteres do chat:
`GetDefaultSpecSkillLine` → `GetConfigIDForSkillLine`/`GetSpecTabIDsForSkillLine` →
`GetTabInfo` (nome + `rootNodeID`) → `GetChildrenForPath` recursivo →
`GetPerksForPath` por folha → `GetDescriptionForPerk` (pra confirmar qual perk é o de
repair). Repetido 3 vezes (uma por track).

**Consequências**: os IDs (`specSkillLineId`, `requiredPerkBySlot`,
`requiredPerkByWeaponBucket`) ficam hardcoded em `Core/RepairTracks.lua`, específicos
deste build do jogo. Uma reestruturação da árvore de especialização ou um level
pruning futuro (mudando os tetos 70/80/90) exigiria repetir essa investigação
manualmente — o passo a passo completo está documentado no plano de trabalho pra
facilitar a próxima vez.

---

## 11. `C_TooltipInfo.GetInventoryItem(...).repairCost` como fonte do valor economizado

**Contexto**: `GetRepairAllCost()` só funciona com `MerchantFrame` aberto — inútil
pro caso de uso do MRH (reparo em campo). A tooltip legada
(`GameTooltip:SetInventoryItem`) também não serve nesse client (retorna só 1 valor,
sem `repairCost`).

**Decisão**: usar a API moderna de Tooltip Data, `C_TooltipInfo.GetInventoryItem(unit,
slotId).repairCost` — validada in-game como disponível em qualquer lugar (inclusive
dungeon e combate), sem depender de vendor por perto.

**Consequências**: elimina a necessidade de qualquer estimativa por fórmula (que era
o plano B caso essa API não funcionasse em campo) — o valor é exato e sempre
disponível.

---

## Referências

- RFC: [rfc-features-2026-07.md](./rfc-features-2026-07.md)
- Plano de trabalho / histórico completo de investigação in-game:
  [plano-features-2026-07.md](./plano-features-2026-07.md)
