require_relative 'lane_manager_base.rb'

module Fastlane
  class SwiftLaneManager < LaneManagerBase
    # @param lane_name The name of the lane to execute
    # @param parameters [Hash] The parameters passed from the command line to the lane
    # @param env Dot Env Information
    def self.cruise_lane(lane, parameters = nil, env = nil)
      UI.user_error!("lane must be a string") unless lane.kind_of?(String) or lane.nil?
      UI.user_error!("parameters must be a hash") unless parameters.kind_of?(Hash) or parameters.nil?

      # xcodeproj has a bug in certain versions that causes it to change directories
      # and not return to the original working directory
      # https://github.com/CocoaPods/Xcodeproj/issues/426
      # Setting this environment variable causes xcodeproj to work around the problem
      ENV["FORK_XCODE_WRITING"] = "true"

      load_dot_env(env)

      started = Time.now
      e = nil
      begin
        self.ensure_runner_built!
        socket_thread = self.start_socket_thread
        sleep(0.250) while socket_thread[:ready].nil?
        # wait on socket_thread to be in ready state, then start the runner thread
        runner_thread = self.cruise_swift_lane_in_thread(lane, parameters)

        runner_thread.join
        socket_thread.join
      rescue Exception => ex # rubocop:disable Lint/RescueException
        # We also catch Exception, since the implemented action might send a SystemExit signal
        # (or similar). We still want to catch that, since we want properly finish running fastlane
        # Tested with `xcake`, which throws a `Xcake::Informative` object

        print_lane_context
        UI.error ex.to_s if ex.kind_of?(StandardError) # we don't want to print things like 'system exit'
        e = ex
      end

      duration = ((Time.now - started) / 60.0).round

      finish_fastlane(nil, duration, e)
    end

    def self.display_lanes
      self.ensure_runner_built!
      Actions.sh(%(#{FastlaneCore::FastlaneFolder.swift_runner_path} lanes))
    end

    def self.cruise_swift_lane_in_thread(lane, parameters = nil)
      if parameters.nil?
        parameters = {}
      end

      parameter_string = ""
      parameters.each do |key, value|
        parameter_string += " #{key} #{value}"
      end

      return Thread.new do
        Actions.sh(%(#{FastlaneCore::FastlaneFolder.swift_runner_path} lane #{lane}#{parameter_string} > /dev/null))
      end
    end

    def self.swap_paths_in_target(target: nil, file_refs_to_swap: nil, expected_path_to_replacement_path_tuples: nil)
      made_project_updates = false
      file_refs_to_swap.each do |file_ref|
        expected_path_to_replacement_path_tuples.each do |preinstalled_config_relative_path, user_config_relative_path|
          next unless file_ref.path == preinstalled_config_relative_path

          file_ref.path = user_config_relative_path
          made_project_updates = true
        end
      end
      return made_project_updates
    end

    # Find all the config files we care about (Deliverfile, Gymfile, etc), and build tuples of what file we'll look for
    # in the Xcode project, and what file paths we'll need to swap (since we have to inject the user's configs)
    #
    # Return a mapping of what file paths we're looking => new file pathes we'll need to inject
    def self.collect_tool_paths_for_replacement(all_user_tool_file_paths: nil, look_for_new_configs: nil)
      new_user_tool_file_paths = all_user_tool_file_paths.select do |user_config, preinstalled_config_relative_path, user_config_relative_path|
        if look_for_new_configs
          File.exist?(user_config)
        else
          !File.exist?(user_config)
        end
      end

      # Now strip out the fastlane-relative path and leave us with xcodeproj relative paths
      new_user_tool_file_paths = new_user_tool_file_paths.map do |user_config, preinstalled_config_relative_path, user_config_relative_path|
        if look_for_new_configs
          [preinstalled_config_relative_path, user_config_relative_path]
        else
          [user_config_relative_path, preinstalled_config_relative_path]
        end
      end
      return new_user_tool_file_paths
    end

    # open and return the swift project
    def self.runner_project
      runner_project_path = FastlaneCore::FastlaneFolder.swift_runner_project_path
      require 'xcodeproj'
      project = Xcodeproj::Project.open(runner_project_path)
      return project
    end

    # return the FastlaneRunner build target
    def self.target_for_fastlane_runner_project(runner_project: nil)
      fastlane_runner_array = runner_project.targets.select do |target|
        target.name == "FastlaneRunner"
      end

      # get runner target
      runner_target = fastlane_runner_array.first
      return runner_target
    end

    def self.target_source_file_refs(target: nil)
      return target.source_build_phase.files.to_a.map(&:file_ref)
    end

    def self.first_time_setup
      setup_message = ["fastlane is now configured to use a swift-based Fastfile (Fastfile.swift) 🦅"]
      setup_message << "To edit your new Fastfile.swift, type: `open #{FastlaneCore::FastlaneFolder.swift_runner_project_path}`"

      # Go through and link up whatever we generated during `fastlane init swift` so the user can edit them easily
      self.link_user_configs_to_project(updated_message: setup_message.join("\n"))
    end

    def self.link_user_configs_to_project(updated_message: nil)
      tool_files_folder = FastlaneCore::FastlaneFolder.path

      # All the tools that could have <tool name>file.swift their paths, and where we expect to find the user's tool files.
      all_user_tool_file_paths = TOOL_CONFIG_FILES.map do |tool_name|
        [
          File.join(tool_files_folder, "#{tool_name}.swift"),
          "../#{tool_name}.swift",
          "../../#{tool_name}.swift"
        ]
      end

      # Tool files the user now provides
      new_user_tool_file_paths = collect_tool_paths_for_replacement(all_user_tool_file_paths: all_user_tool_file_paths, look_for_new_configs: true)

      # Tool files we provide AND the user doesn't provide
      user_tool_files_possibly_removed = collect_tool_paths_for_replacement(all_user_tool_file_paths: all_user_tool_file_paths, look_for_new_configs: false)

      fastlane_runner_project = self.runner_project
      runner_target = target_for_fastlane_runner_project(runner_project: fastlane_runner_project)
      target_file_refs = target_source_file_refs(target: runner_target)

      # Swap in all new user supplied configs into the project
      project_modified = swap_paths_in_target(
        target: runner_target,
        file_refs_to_swap: target_file_refs,
        expected_path_to_replacement_path_tuples: new_user_tool_file_paths
      )

      # Swap out any configs the user has removed, inserting fastlane defaults
      project_modified ||= swap_paths_in_target(
        target: runner_target,
        file_refs_to_swap: target_file_refs,
        expected_path_to_replacement_path_tuples: user_tool_files_possibly_removed
      )

      if project_modified
        fastlane_runner_project.save
        updated_message ||= "Updated #{FastlaneCore::FastlaneFolder.swift_runner_project_path}"
        UI.success(updated_message)
      else
        UI.success("FastlaneSwiftRunner project is up-to-date")
      end

      return project_modified
    end

    def self.start_socket_thread
      require 'fastlane/server/socket_server'
      require 'fastlane/server/socket_server_action_command_executor'

      return Thread.new do
        command_executor = SocketServerActionCommandExecutor.new
        server = Fastlane::SocketServer.new(command_executor: command_executor)
        server.start
      end
    end

    def self.ensure_runner_built!
      UI.verbose("Checking for new user-provided tool configuration files")
      # if self.link_user_configs_to_project returns true, that means we need to rebuild the runner
      runner_needs_building = self.link_user_configs_to_project

      if FastlaneCore::FastlaneFolder.swift_runner_built?
        runner_last_modified_age = File.mtime(FastlaneCore::FastlaneFolder.swift_runner_path).to_i
        fastfile_last_modified_age = File.mtime(FastlaneCore::FastlaneFolder.fastfile_path).to_i

        if runner_last_modified_age < fastfile_last_modified_age
          # It's older than the Fastfile, so build it again
          UI.verbose("Found changes to user's Fastfile.swift, setting re-build runner flag")
          runner_needs_building = true
        end
      else
        # Runner isn't built yet, so build it
        UI.verbose("No runner found, setting re-build runner flag")
        runner_needs_building = true
      end

      if runner_needs_building
        self.build_runner!
      end
    end

    def self.build_runner!
      UI.verbose("Building FastlaneSwiftRunner")
      require 'fastlane_core'
      require 'gym'
      require 'gym/generators/build_command_generator'

      project_options = {
          project: FastlaneCore::FastlaneFolder.swift_runner_project_path,
          skip_archive: true
        }
      Gym.config = FastlaneCore::Configuration.create(Gym::Options.available_options, project_options)
      build_command = Gym::BuildCommandGenerator.generate

      FastlaneCore::CommandExecutor.execute(
        command: build_command,
        print_all: false,
        print_command: !Gym.config[:silent],
        error: proc do |output|
          ErrorHandler.handle_build_error(output)
        end
      )
    end
  end
end
