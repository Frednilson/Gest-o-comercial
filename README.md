# Gestão Comercial

Aplicação Android (Flutter + Dart) de gestão comercial **offline** para pequenos e médios estabelecimentos em Moçambique. Moeda: Metical (MZN). Dados em SQLite.

## Como executar

1. Instalar o Flutter estável (Dart >= 3.4) e o Android SDK.
2. Na pasta do projecto, gerar a parte Android (só na primeira vez; não altera `lib/` nem `pubspec.yaml`):
   ```
   flutter create . --platforms=android --org mz.gestaocomercial --project-name gestao_comercial
   ```
3. Configuração Android (obrigatória para o scanner):
   - `android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>` (antes de `<application>`):
     ```xml
     <uses-permission android:name="android.permission.CAMERA"/>
     <uses-feature android:name="android.hardware.camera" android:required="false"/>
     ```
   - `android/app/build.gradle` (ou `build.gradle.kts`): `minSdk` = **23** (`minSdkVersion 23` / `minSdk = 23`).
4. `flutter pub get`
5. `flutter analyze` e `flutter test` (testes de base de dados, vendas e stock)
6. `flutter run` (telemóvel ou emulador)
7. APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`

Na primeira execução são carregados dados de demonstração (12 produtos, clientes, fornecedores, despesas e vendas dos últimos 7 dias). Em *Mais → Configurações* pode recarregá-los ou apagar tudo para começar do zero.

## Funcionalidades

- **Início**: vendas do dia, nº de vendas, produtos, stock baixo, despesas, lucro estimado, gráfico de 7 dias, mais vendidos, últimas vendas (tudo lido da base de dados).
- **Produtos**: CRUD, categorias, pesquisa por nome/código, fotografia, código de barras (manual ou câmara, único).
- **Vendas**: pesquisa manual ou leitura por câmara (várias leituras seguidas, anti-duplicação, "Produto não cadastrado. Deseja cadastrar?"), carrinho, desconto, cliente, pagamento (dinheiro, M-Pesa, e-Mola, transferência, misto), troco, valor em falta (venda pendente), cancelamento com reposição de stock, recibo PDF (guardar, partilhar, imprimir).
- **Stock**: entradas, saídas, devoluções, ajustes, alertas de reposição, histórico (sem stock negativo).
- **Mais**: clientes (histórico de compras e dívida), fornecedores (histórico de fornecimento), despesas (filtro por período), relatórios em PDF, configurações (estabelecimento, logótipo, tema, cópias de segurança).

## Regras de negócio garantidas

Todas as vendas passam por **uma única transacção SQLite** (venda + itens + pagamentos + stock + movimentações). Stock negativo e preços negativos são rejeitados na aplicação *e* pela própria base de dados (`CHECK`). Cada tentativa de venda tem um *token* único: um duplo toque não regista duas vendas. Preço e custo unitário ficam guardados no item da venda (lucro histórico correcto). Produtos com vendas são desactivados em vez de apagados.

## Arquitectura

- `lib/core/` tema, constantes, SQLite (`database_helper.dart`, `demo_data.dart`), utilitários, widgets reutilizáveis.
- `lib/models/` entidades. `lib/services/` acesso a dados (únicos a falar com SQLite; ponto de extensão para sincronização futura com API/Firebase).
- `lib/providers/` estado (Provider). `AppData` é um barramento: qualquer alteração faz recarregar os ecrãs afectados.
- `lib/features/<módulo>/screens|widgets|services|providers` ecrãs por módulo. `lib/app/` raiz, rotas, navegação inferior.

## Estado de verificação

O código foi escrito e revisto estaticamente (imports, tipos, regras de negócio), mas **ainda não foi compilado nem executado** num ambiente com Flutter. Corra `flutter analyze` e `flutter test` e, se aparecer algum erro, envie a mensagem para ser corrigida.
