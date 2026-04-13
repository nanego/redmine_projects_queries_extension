# Redmine Projects-Queries Extension plugin

This plugin adds new filters and columns to projects queries.

It is only compatible with Redmine 4.1.0 and above.

This plugin is a fork from the [Better CrossProjects](https://github.com/jbbarth/redmine_better_crossprojects) plugin and you should continue to use this one if you are running Redmine 4.0.x or Redmine 3.


## Installation

Please apply general instructions for plugins [here](http://www.redmine.org/wiki/redmine/Plugins).

Requirements:

    ruby >= 2.7.0
    
Note that this plugin now depends on:
* **redmine_base_deface** which can be found [here](https://github.com/jbbarth/redmine_base_deface)

First, download the source or clone the plugin and put it in the "plugins/" directory of your redmine instance. Note that this is crucial that the directory is named 'redmine_projects_queries_extension' !

Then execute:

    $ bundle install
    $ rake redmine:plugins

And finally, restart your Redmine instance.

This plugin is only compatible with Redmine 4.1.0 and above.
Please feel free to report any bug you encounter.

## Test status

|Plugin branch| Redmine Version | Test Status       |
|-------------|-----------------|-------------------|
|master       | 6.0.9           | [![6.0.9][1]][5]  |
|master       | 6.1.2           | [![6.1.2][2]][5]  |
|master       | master          | [![master][3]][5] |

[1]: https://github.com/nanego/redmine_projects_queries_extension/actions/workflows/6_0_9.yml/badge.svg
[2]: https://github.com/nanego/redmine_projects_queries_extension/actions/workflows/6_1_2.yml/badge.svg
[3]: https://github.com/nanego/redmine_projects_queries_extension/actions/workflows/master.yml/badge.svg
[5]: https://github.com/nanego/redmine_projects_queries_extension/actions

## Columns added to the /projects page

The plugin adds the following columns to the project list:

### Static columns

| Column | Label | Admin only |
|--------|-------|------------|
| `updated_on` | Updated on | No |
| `activity` | Activity | No |
| `issues` | Issues | No |
| `role` | Role | No |
| `members` | Members | No |
| `users` | Users | No |
| `description` | Description | No |
| `organizations` | Organizations (requires `redmine_organizations` plugin) | No |

### Dynamic columns per role

One column is generated for each non-built-in role defined in Redmine. Requires the `redmine_organizations` plugin.

| Column | Label | Admin only |
|--------|-------|------------|
| `role_{id}` | Role name | No |
| `role_emails_{id}` | Role emails - {role name} | **Yes** |

### Dynamic columns per function

One column is generated for each function defined in Redmine. Requires both `redmine_organizations` and `redmine_limited_visibility` plugins.

| Column | Label | Admin only |
|--------|-------|------------|
| `function_{id}` | Function name | No |
| `function_emails_{id}` | Function emails - {function name} | **Yes** |

### Dynamic columns per tracker

One column is generated for each tracker defined in Redmine.

| Column | Label | Admin only |
|--------|-------|------------|
| `last_issue_date_for_tracker_{id}` | Last issue {tracker name} | No |

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
