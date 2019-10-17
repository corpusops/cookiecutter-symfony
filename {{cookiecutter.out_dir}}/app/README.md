# {{ cookiecutter.name }}

## Après chaque pull

```sh
# Mettre à jour les dépendances
./control.sh userexec bin/composerinstall

# Lancer les mises à jour du schéma des autres
./control.sh console doctrine:migrations:migrate --allow-no-migration
```

## Lancer les tests unitaires

```sh
bin/phpunit
```

## Lancer les tests EndToEnd (e2e) Cypress

Il y a trois modes d'actions de Cypress

- en interne, un container docker fait tourner les tests vers la cible que vous désignez, et après vous avez les screenshots et vidéos dans le dossier `e2e/cypress/[screenshots|videos]`
- avec une jolie GUI, qui vous pilote un chrome local, très utile en phase d'écriture. Pour ce mode votre propre npm local sera utilisé et cypress sera downloadé en local
- dans la CI, après le déploiement du serveur de dev, si vous lancez la tâche e2e ils tourneront dans un docker de la CI, en ciblant le serveur de dev. En cas de problèmes vous avez dans l'écran de la CI des **artefacts** à durée de 4 heures qui contiennent les screenshots et vidéos

### Ouvrir la GUI cypress

Par rapport à l'autre solution, expliquée en dessous avec le **run**, celle ci à l'avantage d'avoir une jolie interface, mais le gros désavantage de nécessiter une installation npm+cypress locale (dans le sous dossier `e2e/nodes_modules`).

La commande se charge de l'installation, mais il est *préférable* d'avoir installé `nvm`, si possible, comme ça le script utilise de base un npm stable via nvm.

```bash
# la GUI s'ouvre et tapera sur le site qui tourne avec docker-compose
./control.sh cypress_open_local
# la GUI s'ouvrira et tapera sur le serveur de dev
./control.sh cypress_open_dev
# La gui s'ouvrira et tapera où vous voulez
./control.sh cypress_open http://www.example.com
```

### Faire tourner les tests sans la gui

```bash
# le docker cypress fera tourner les tests sur votre installation docker-compose
./control.sh cypress_run_local
# le docker cypress fera tourner les tests sur le serveur de dev
./control.sh cypress_run_dev
# le docker cypress fera tourner les tests où vous voulez
./control.sh cypress_run http://www.example.com
```

## Générer la documentation

```sh
# La première fois
pip install --user virtualenv
mkdir ~/venvs
virtualenv ~/venvs/sphinx
. ~/venvs/sphinx/bin/activate
pip install sphinx
pip install sphinx_rtd_theme

# Regénérer la documentation
. ~/venvs/sphinx/bin/activate
cd docs/
make html
```

Vous pouvez ensuite la consulter en chargeant le fichier `docs/_build/html/index.html`
dans le navigateur de votre choix.
