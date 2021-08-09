# PlugAttack

## v0.4.3 (09.08.2021)

* Fix static :block response in fail2ban rule

## v0.4.2 (02.08.2019)

* Use fully qualified function names in generated functions, to avoid issues
  if `Plug.Conn` is not imported.

## v0.4.1 (21.10.2018)

* Support `child_spec/1` function

## v0.4.0 (28.07.2018)

* Don't use deprecated time units
* Require elixir 1.4

## v0.3.1 (09.04.2018)

* Don't use parse transforms - they are deprecated
* Fix dialyzer issues with generated code

## v0.3.0 (27.02.2017)

* Introduce `PlugAttack.Storage.Ets.clean/1`

## v0.2.0 (17.11.2016)

* Introduce `PlugAttack.Route.fail2ban/2`

## v0.1.0 (12.11.2016)

* Initial release
