# discourse-westan-ranking

Plugin Discourse independente para exibir o **Ranking Semanal** de engajamento da comunidade.

## Funcionalidades

- Rota pública `/ranking`.
- Ranking semanal automático considerando a semana anterior, de segunda a domingo.
- Pontuação configurável: posts, tópicos e multiplicador VIP.
- Modal explicativo fiel ao layout do app original.
- Painel de configuração para staff.
- Exclusão manual de usuários do ranking.
- Link no menu nativo do Discourse.

## Instalação

No `app.yml` do Discourse:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/forumwestan/discourse-westan-ranking.git
```

Depois rode:

```bash
./launcher rebuild app
```

## Configuração

Em **Admin → Settings → Plugins**:

| Setting | Descrição |
|---|---|
| `westan_ranking_enabled` | Habilita `/ranking` |
| `westan_ranking_vip_group` | Grupo que recebe multiplicador VIP, por exemplo `vip` |

## Endpoints

```text
GET   /westan/ranking
PATCH /westan/ranking/config
GET   /westan/ranking/users
```
