# doc-o-tron

Documentation bot for [rapture](https://github.com/swarley/rapture).
However, it can be used genericially for yard documented ruby projects.

### Getting Started
Run the following commands

```sh
git clone --recursive https://github.com/swarley/doc-o-tron
cd doc-o-tron
bundle install
bundle exec yard doc rapture
# Make sure to create a config.yml at this point
# based on example_config.yml
bundle exec ruby main.rb
```
