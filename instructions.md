# PLANO — PACKAGE WEBSOCKET BACKEND EM DART (`dart:io`)

## Visão do package

**O que ele é**

* Um **core WebSocket backend** em Dart
* Transporte WebSocket **puro**
* Controle explícito de sessão, reconexão, salas e protocolo
* Backend-only

**O que ele NÃO é**

* Não é framework web
* Não é ORM
* Não é solução mágica de escala
* Não esconde lógica crítica

👉 Isso precisa ficar claro já na descrição do pub.dev.

---

## Stack fixa do package

* **Linguagem:** Dart
* **Runtime:** Dart VM
* **Dependência base:** `dart:io`
* **Target:** server
* **Zero dependências obrigatórias externas**

Dependências opcionais **só via adapters** (ex: Redis, JWT).

---

## Princípios do package (contrato filosófico)

Esses princípios precisam estar no README, sem rodeio:

1. WebSocket é transporte, não domínio
2. Sessão > conexão
3. Protocolo explícito sempre
4. Reconexão é responsabilidade do servidor
5. Escala exige mensageria externa
6. Nada acontece de forma implícita

Se alguém não concorda com isso, **não é o público do package**.

---

## Escopo do package (o que ele entrega)

### O package entrega:

* gerenciamento de conexões
* gerenciamento de sessões
* autenticação hookável
* reconexão controlada
* prevenção de sessão duplicada
* salas lógicas
* versionamento de protocolo
* eventos bem definidos
* pontos de extensão claros

### O package NÃO entrega:

* banco de dados
* cache
* UI
* load balancer
* infraestrutura de mensageria
* lógica de negócio

---

## Módulos conceituais do package

### 1️⃣ Core de transporte

Responsabilidade:

* aceitar upgrade WebSocket
* manter socket aberto
* receber e enviar mensagens
* encerrar conexão corretamente

Regra:

* não conhece domínio
* não conhece auth
* não conhece salas

---

### 2️⃣ Gerenciamento de conexão

Responsabilidade:

* gerar `connectionId`
* registrar conexão
* detectar queda
* emitir eventos de lifecycle

Estado:

* ativa
* encerrada
* inválida

---

### 3️⃣ Gerenciamento de sessão

Responsabilidade:

* criar `sessionId`
* associar sessão ↔ conexão
* manter estado mínimo
* permitir troca de conexão

Regras:

* sessão sobrevive à queda
* sessão é única
* uma sessão ativa por vez

Isso resolve:

* reconexão
* duplicação
* background de app
* troca de rede

---

### 4️⃣ Autenticação (plugável)

Responsabilidade:

* validar identidade
* associar `userId` à sessão
* rejeitar acesso inválido

Decisão de design:

* auth **não é implementada**
* auth é **interface/hook**

Exemplos no README:

* JWT
* token custom
* API key

Sem dependência forçada.

---

### 5️⃣ Detecção de queda

Responsabilidade:

* heartbeat
* timeout
* marcar sessão como suspensa

Estado da sessão:

* ativa
* suspensa
* encerrada

Isso habilita reconexão limpa.

---

### 6️⃣ Reconexão

Responsabilidade:

* aceitar nova conexão
* validar `sessionId`
* encerrar conexão antiga
* reapontar sessão
* disparar eventos

Regra imutável:

> uma sessão = uma conexão ativa

---

### 7️⃣ Restauração de estado

Responsabilidade:

* permitir reenvio de estado mínimo
* fornecer hook de restauração

Regra:

* estado pesado nunca fica no socket
* o package **coordena**, não armazena

---

### 8️⃣ Salas

Responsabilidade:

* criar sala lógica
* entrada/saída de sessões
* broadcast local

Regra:

* sala conhece sessões
* sala não conhece sockets

Isso evita bug clássico de reconexão.

---

### 9️⃣ Protocolo de mensagens

Responsabilidade:

* validar estrutura
* expor versão
* expor evento/tipo
* carregar payload

Decisão:

* protocolo é obrigatório
* formato implícito não existe

---

### 🔟 Versionamento de protocolo

Responsabilidade:

* validar versão da mensagem
* rotear para handler compatível
* permitir fallback

Regra:

* cliente antigo não quebra silenciosamente
* servidor decide compatibilidade

Documentação obrigatória no repo:

* versão
* eventos
* payload
* breaking changes

---

### 1️⃣1️⃣ Dispatcher

Responsabilidade:

* mapear evento → handler
* aplicar validações
* retornar resposta

Regra:

* WebSocket não chama domínio direto
* dispatcher é o limite

---

### 1️⃣2️⃣ Escala — responsabilidade explícita

Decisão arquitetural clara:

* o package **não escala sozinho**
* ele fornece **interfaces** para:

  * Pub/Sub
  * event bus
  * broadcast externo

Adapters opcionais:

* Redis Pub/Sub
* NATS

Kafka fica fora do core (documentado como overkill).

---

### 1️⃣3️⃣ Observabilidade

Responsabilidade:

* métricas básicas
* eventos de lifecycle
* hooks para logging externo

Nada embutido.
Nada opinativo.

---

## Estrutura do package (conceitual)

O README deve deixar claro que existe:

* core
* hooks
* adapters opcionais
* exemplos fora do core

Nada de monólito.

---

## Versionamento do package

Regra simples:

* mudanças de protocolo = major
* novos recursos compatíveis = minor
* bugfix = patch

Sem exceção.

---

## README (obrigatório, sem papo mole)

O README precisa responder rápido:

1. O que esse package resolve
2. O que ele NÃO resolve
3. Quando usar
4. Quando NÃO usar
5. Conceitos principais
6. Fluxo de conexão
7. Fluxo de reconexão
8. Como escalar
9. Exemplos reais (simples)

Se não der pra entender em 5 minutos, falhou.

---

## Posicionamento no pub.dev (muito importante)

Esse package deve se vender como:

> **Core WebSocket Backend para Dart — explícito, performático e sem abstrações mágicas**

Não como:

* “framework”
* “Socket.IO killer”
* “solução completa”

Isso atrai o público certo e evita issues idiotas.


Package:

Perfeito. Vou te entregar **um plano simples, direto, sem estimativa de tempo, sem código, sem framework, sem abstração inútil**.
Isso aqui é **checklist de arquiteto**, não tutorial de blog.

**Stack fixa (não muda):**

* **Linguagem:** Dart
* **Runtime:** Dart VM
* **Lib:** `dart:io`
* **Contexto:** Backend only (sem Flutter)
* **Objetivo:** Controle total, performance previsível, zero mágica

---

# PLANO SIMPLES — WEBSOCKET PRÓPRIO EM DART (`dart:io`)

---

## 1️⃣ Fundamento inegociável

**WebSocket é transporte, não regra de negócio.**

Decisão:

* WebSocket só:

  * aceita conexão
  * recebe mensagem
  * valida
  * despacha
  * responde
* Nada de lógica de domínio dentro do socket.

Resultado:

* código previsível
* fácil de trocar transporte depois
* zero acoplamento burro

---

## 2️⃣ Identidade de conexão (base de tudo)

Você **NÃO** confia na conexão, você confia na **identidade**.

Defina:

* `connectionId` (único por conexão)
* `sessionId` (único por usuário/sessão lógica)
* `userId` (após auth)

Regra:

* conexão é descartável
* sessão é persistente

Isso resolve **reconexão, duplicação e restauração de estado**.

---

## 3️⃣ Autenticação (auth pronta, simples e controlável)

Estratégia:

* autenticação **no handshake** ou **na primeira mensagem**
* token curto (JWT ou similar)
* token inválido → socket fechado imediatamente

Estado mínimo mantido:

* userId
* sessionId
* permissões

Regra de ouro:

* **refresh de auth = nova conexão**
* nada de refresh token dentro do socket

Controle total, zero ambiguidade.

---

## 4️⃣ Detecção de queda (sem fantasia)

Você NÃO confia em `onDone` apenas.

Você implementa:

* heartbeat (ping/pong)
* timeout de inatividade
* marcação de sessão como “desconectada”

Estado:

* sessão ativa
* sessão suspensa
* sessão encerrada

Isso é o que permite reconexão decente.

---

## 5️⃣ Reconexão (sem duplicar sessão)

Fluxo:

1. cliente reconecta
2. envia `sessionId`
3. servidor verifica:

   * sessão existe?
   * sessão já ativa?
4. se sim:

   * encerra conexão antiga
   * vincula nova conexão à sessão
5. restaura estado mínimo

Regra clara:

* **uma sessão = uma conexão ativa**

Nada de gambiarra.

---

## 6️⃣ Restauração de estado (mínimo viável)

Você NÃO replica tudo.

Você mantém:

* estado essencial da sessão
* últimas mensagens críticas (se necessário)
* posição lógica do usuário

Nada de:

* replay infinito
* histórico pesado em memória

Estado grande:

* banco
* cache externo
* nunca no socket

---

## 7️⃣ Salas (simples e controlável)

Sala não é socket.
Sala é **estrutura lógica**.

Modelo:

* sala = identificador
* sessão entra / sai
* socket apenas aponta pra sessão

Regras:

* socket pode cair
* sessão continua na sala
* reconexão reaponta

Resultado:

* menos bugs
* menos acoplamento
* mais controle

---

## 8️⃣ Protocolo (onde a maioria erra)

Você **define isso ANTES** de crescer.

Decisão:

* toda mensagem tem:

  * versão
  * tipo/evento
  * payload

Você **nunca** depende de formato implícito.

---

## 9️⃣ Versionamento de protocolo (obrigatório)

Você aceita que:

* cliente velho existe
* update não é simultâneo

Estratégia:

* versão explícita por mensagem
* servidor entende:

  * versão atual
  * versões anteriores suportadas

Compatibilidade:

* adapta mensagem internamente
* nunca quebra silenciosamente

Documentação:

* versão
* eventos
* payload
* comportamento esperado

Sem isso, o sistema morre cedo.

---

## 🔟 Organização interna (sem abstração burra)

Camadas claras:

* transporte (WebSocket)
* parser de protocolo
* validador
* dispatcher
* domínio

Regra:

* WebSocket **nunca decide nada**
* ele só encaminha

Performance vem disso.

---

## 1️⃣1️⃣ Escala — um servidor

Cenário:

* memória compartilhada
* `Set` de conexões
* salas em memória

Aceitável:

* MVP
* carga controlada
* baixo custo

Limite claro:

* quando subir outro nó → muda estratégia

---

## 1️⃣2️⃣ Escala — múltiplos servidores (ponto crítico)

Problema:

* cada nó tem seus sockets
* broadcast quebra

Decisão arquitetural:

* WebSocket não escala sozinho
* mensageria é obrigatória

Opções reais:

* Redis Pub/Sub (padrão)
* NATS (mais avançado)
* Kafka (overkill, só se souber o que está fazendo)

Fluxo:

* evento entra em um nó
* publica no broker
* outros nós recebem
* cada nó entrega localmente

Sem isso, não existe “escala”.

---

## 1️⃣3️⃣ Sticky sessions (opcional, consciente)

Só use se:

* entende load balancer
* aceita limitação
* quer simplificar no início

Nunca confie nisso a longo prazo.

---

## 1️⃣4️⃣ Observabilidade mínima

Você precisa saber:

* conexões ativas
* sessões ativas
* reconexões
* quedas
* latência

Sem isso:

* você voa cego
* debug vira achismo

---

## 1️⃣5️⃣ Regra final (a mais importante)

> **Protocolo é ativo. Transporte é descartável.**

Se amanhã você trocar:

* WebSocket → SSE
* WebSocket → gRPC stream
* WebSocket → outro runtime

Nada quebra, porque:

* protocolo é estável
* domínio está isolado


