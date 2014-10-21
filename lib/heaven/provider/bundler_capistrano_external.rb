require "heaven/provider/bundler_capistrano"

module Heaven
  # Top-level module for providers.
  module Provider
    # A capistrano provider that installs gems.
    class BundlerCapistranoExternal < BundlerCapistrano
      def initialize(guid, payload)
        super
        @name = "bundler_capistrano_external"
      end

      def execute
        return execute_and_log(["/usr/bin/true"]) if Rails.env.test?

        unless File.exist?(checkout_directory)
          log "Cloning #{deploy_recipe_clone_url} into #{checkout_directory}"
          execute_and_log(["git", "clone", deploy_recipe_clone_url, checkout_directory])
        end

        Dir.chdir(checkout_directory) do
          log "Fetching the latest code"
          execute_and_log(%w{git fetch})
          execute_and_log(["git", "reset", "--hard", 'origin/master'])
          Bundler.with_clean_env do
            bundler_string = ["bundle", "install", "--without", ignored_groups.join(" ")]
            log "Executing bundler: #{bundler_string.join(" ")}"
            execute_and_log(bundler_string)
            deploy_string = ["bundle", "exec", "cap", environment, "-s", "branch=#{ref}", task]
            log "Executing capistrano: #{deploy_string.join(" ")}"
            execute_and_log(deploy_string, "BRANCH" => ref)
          end
        end
      end

      private

      def deploy_recipe_clone_url
        deploy_recipe_url = custom_payload.try(:[], 'deploy_recipe_clone_url')
        if !deploy_recipe_url
          fail 'No deploy recipe'
        end
        uri = Addressable::URI.parse(deploy_recipe_url)
        uri.user = github_token
        uri.password = ""
        uri.to_s
      end
    end
  end
end
