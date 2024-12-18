# Terraform Stacks

- https://www.hashicorp.com/blog/terraform-stacks-explained

This allows writing Stacks (the wording doesn't really apply to our use-case) which can replace root modules.

## Idea

1. Have one component that sets up Traefik and DNS together
  - This is like the basic setup to make requests to the cluster
  - Use [HTTP DataSource](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http#usage-with-provisioner) and [provisioners](https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax#failure-behavior) to verify if a request to the Traefik Admin Dashboard/Ping endpoint goes through
  - If not, partially apply and bail. This will happen when setting up from absolute scratch, so we can take a pause and setup DNS on the client machine/router
  - After, apply again to continue
2. Have another component to setup Gotify
  - This can then be used to initialize the Gotify Provider, which other components can then use
  - Using the provider creates the depenency chain implicitly
  - This gets rid of race conditions and removes the need to do explicit `depends_on` clauses
3. Have a component that does other infra stuff
  - Like Redis
  - or Postgres (again, the component initializes the postgres provider, which can then be used _afterwards_)
  - This can also contain required setup code
4. Each application deployment is now a component
  - They create dependencies by simply using outputs/providers from previous steps
  - Allows applying from 0 to full in one run without race conditions

## Problem

- Currently, this is only available in Public Beta, which they say might break backwards compatibility
- It's currently only available in the Hashi Cloud, which I don't _want_ to use (local `terraform apply` only)
- It will probably be in Terraform Enterprise first before its in the community edition

