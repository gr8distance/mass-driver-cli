# mass-driver-cli

CLI tool for [mass-driver](https://github.com/gr8distance/mass-driver) web framework.

Generates project scaffolds, handlers, models, and components.

## Install

```bash
git clone https://github.com/gr8distance/mass-driver-cli
cd mass-driver-cli
area51 install && area51 build
sudo cp bin/mass-driver-cli /usr/local/bin/mass-driver
```

## Commands

### `mass-driver new <name> [options]`

Create a new mass-driver project.

```bash
mass-driver new my-app                            # Full stack + SQLite
mass-driver new my-api --api                      # API only (no HTML views)
mass-driver new my-app --database postgres        # With PostgreSQL + docker-compose
mass-driver new my-app --database mysql           # With MySQL + docker-compose
mass-driver new my-site --database nil            # No database
mass-driver new my-api --api --database nil       # Minimal API
```

### `mass-driver gen.handler <name>`

Generate a handler with index/show/create actions.

```bash
mass-driver gen.handler users
# => src/web/handlers/users.lisp
# Prints route suggestions to add to your router
```

### `mass-driver gen.model <name> [field:type ...]`

Generate domain entity, infra repository, and migration.

```bash
mass-driver gen.model post title:string body:text published:boolean
# => src/domain/post/package.lisp
# => src/domain/post/post.lisp
# => src/infra/repo/post-repo.lisp
# => migrations/20260415_create_posts.lisp
```

Supported types: `string`, `text`, `integer`, `boolean`, `datetime`

### `mass-driver gen.component <name>`

Generate a UI component.

```bash
mass-driver gen.component modal
# => src/web/components/modal.lisp
```

## License

MIT
