require 'socket'

module VagrantPlugins
  module OpenStack
    module Action
      class PrepareNFSSettings
        def initialize(app,env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::action::vm::nfs")
        end

        def call(env)
          @app.call(env)
          @machine = env[:machine]
          @openstack = env[:openstack_compute]
          @floating_ip = env[:floating_ip]


          if using_nfs?
            config =  env[:machine].provider_config
            if config.nfs_host_ip.nil? or config.nfs_host_ip.empty?
              env[:nfs_host_ip] = read_host_ip
            else
              env[:nfs_host_ip] = config.nfs_host_ip
            end
            env[:nfs_machine_ip] = read_machine_ip
          end
        end

        def using_nfs?
          @machine.config.vm.synced_folders.any? { |_, opts| opts[:type] == :nfs }
        end

        # Returns the IP address of the host
        #
        # @param [Machine] machine
        # @return [String]
        def read_host_ip
          ip=nil
          #Get First private ip
          Socket.ip_address_list.detect do |intf|
            if intf.ipv4_private?
              ip = intf.ip_address
            end
          end

          if ip.nil? or ip.empty?
            @logger.debug("No valid host ip could be found.")
            raise Errors::Exception
          end
          @logger.info("Host IP : " + ip )
          return ip
        end



        # Returns the IP address of the guest by looking at the first
        # enabled host only network.
        #
        # @return [String]
        def read_machine_ip

          id = @machine.id || @openstack.servers.all( :name => @machine.name ).first.id rescue nil
          return nil if id.nil?
          server = @openstack.servers.get(id)
          if server.nil?
            # The machine can't be found
            @logger.info("Machine couldn't be found, assuming it got destroyed.")
            @machine.id = nil
            return nil
          end

          config = @machine.provider_config

          # Print a list of the available networks
          server.addresses.each do |network_name, network_info|
            @logger.debug("OpenStack Network Name: #{network_name}")
          end

          if config.network
            host = server.addresses[config.network].last['addr'] rescue nil
          else
            if config.address_id.to_sym == :floating_ip
              host = @floating_ip
            else
              host = server.addresses[config.address_id].last['addr'] rescue nil
            end
          end

          # If host is still nil, try to find the IP address another way
          if host.nil?
            @logger.debug("Was unable to determine what network to use. Trying to find a valid IP to use.")
            if server.public_ip_addresses.length > 0
              @logger.debug("Public IP addresses available: #{server.public_ip_addresses}")
              if @floating_ip
                if server.public_ip_addresses.include?(@floating_ip)
                  @logger.debug("Using the floating IP defined in Vagrantfile.")
                  host = @machine.floating_ip
                else
                  @logger.debug("The floating IP that was specified is not available to this instance.")
                  raise Errors::FloatingIPNotValid
                end
              else
                host = server.public_ip_address
                @logger.debug("Using the first available public IP address: #{host}.")
              end
            elsif server.private_ip_addresses.length > 0
              @logger.debug("Private IP addresses available: #{server.private_ip_addresses}")
              host = server.private_ip_address
              @logger.debug("Using the first available private IP address: #{host}.")
            end
          end

          # If host got this far and is still nil/empty, raise an error or
          # else vagrant will try connecting to localhost which will never
          # make sense in this scenario
          if host.nil? or host.empty?
            @logger.debug("No valid SSH host could be found.")
            raise Errors::SSHNoValidHost
          end

          return host
        end
      end
    end
  end
end
