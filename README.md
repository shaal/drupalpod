# DrupalPod

| <h2>:point_right: Start here</h2>1. Download the DrupalPod browser extension<br>[Chrome](https://chrome.google.com/webstore/detail/drupalpod-helper-extensio/pjfjhkcfkhbemnbpkakjhmboacefmjjl?hl=en), [Firefox](https://addons.mozilla.org/en-US/firefox/addon/drupalpod), or [Safari](https://apps.apple.com/us/app/drupalpod-helper/id1595485286).<br><br>2. Go to any issue page on Drupal.org<br>(core, module, or theme).<br><br>3. Click on the DrupalPod extension.<br><br>4. (Optional) Choose a patch / issue fork / branch.<br><br><hr>:tada: A full Drupal development environment is being generated for you :tada:<br><br>Please submit [feedback, bug reports and feature requests](https://github.com/shaal/DrupalPod/issues/new/choose) | [![DrupalPod logo](https://user-images.githubusercontent.com/22901/122864786-40253c00-d2f3-11eb-959b-61fb6871e3f4.png)](https://gitpod.io/from-referrer/) |
| - | :- |

<br>

## About the project

This project allows you to work on Drupal contributions with a familiar setup of a "normal" Drupal website.\
No computer is needed because it is all running in the cloud.

* Install additional packages - `ddev composer`
* Run Drush commands - `ddev drush <command>`
* Run tests
  * Nightwatch - `ddev nightwatch <arguments>`
  * PHPUnit - `ddev phpunit <arguments>`
* IDE in a browser
  * VScode (default)
  * PHPStorm - run `phpstorm`

<br>

## Project structure

* Every project is cloned into `/repos/<project_name>`
* Required by composer
* Symlinked into a normal Drupal website structure:
  * Core directory `/web/core`
  * Module directory `/web/modules/contrib/module_name`
  * Theme directory `/web/themes/contrib/theme_name`

<br>

## The secret sauce

* [Gitpod](https://www.gitpod.io) - development environment in the cloud
* [DDEV](https://ddev.readthedocs.io/en/stable) - easy setup for PHP projects using Docker
* [DrupalPod](https://chrome.google.com/webstore/detail/drupalpod-helper-extensio/pjfjhkcfkhbemnbpkakjhmboacefmjjl?hl=en
) Browser Extension
* [Drupal Core Development Project](https://github.com/joachim-n/drupal-core-development-project)

<br>

## Pushing code

_\* In order to push code, a **one time** SSH keys setup is required._

From within a Gitpod workspace run:

1. `.gitpod/drupal/ssh/02-setup-private-ssh.sh` \
Follow the instructions on the screen.

1. `.gitpod/drupal/ssh/04-confirm-ssh-setup.sh` \
If SSH keys are valid, it stores your private SSH key as an environment variable in Gitpod.

<br>

## Notes

* Manual SSH setup is a temporary requirement until the Drupal's self-hosted Gitlab gets integrated with Gitpod.

  [WIP - making a friendlier interactive dialog](https://github.com/shaal/DrupalPod/issues/4).

* If you prefer working locally - you can clone this repo to your computer.\
 The only 2 requirements are [Docker](https://ddev.readthedocs.io/en/stable/users/docker_installation/) and [DDEV](https://ddev.readthedocs.io/en/stable/#installation).

<br>

## Thank you

* [Randy Fay](https://github.com/rfay)
* [Joe Still](https://github.com/bioshazard)
* [Joachim](https://github.com/joachim-n)

---

![DrupalPod-logo](https://user-images.githubusercontent.com/22901/122864786-40253c00-d2f3-11eb-959b-61fb6871e3f4.png)
