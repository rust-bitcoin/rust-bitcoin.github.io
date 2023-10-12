default:
  just --list

alias b := build
alias t := test

build:
  cd cookbook && mdbook build

serve:
  cd cookbook && mdbook serve

test:
  cd cookbook/tests && ./generate.sh && cargo test