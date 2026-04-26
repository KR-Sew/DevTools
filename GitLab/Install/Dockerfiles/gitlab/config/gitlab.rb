# External database configuration
external_url 'http://your.gitlab.url'

gitlab_rails['db_adapter'] = 'postgresql'
gitlab_rails['db_encoding'] = 'unicode'
gitlab_rails['db_collation'] = nil
gitlab_rails['db_database'] = 'gitlabhq_production'
gitlab_rails['db_pool'] = 10
gitlab_rails['db_username'] = 'gitlab'
gitlab_rails['db_password'] = 'your_password'
gitlab_rails['db_host'] = 'your_db_host'
gitlab_rails['db_port'] = 5432
