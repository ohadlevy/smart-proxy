module Proxy::Puppet
  extend Proxy::Log
  extend Proxy::Util

  class << self
    def run *hosts
      if SETTINGS.puppetrun == "mcollective"
        Proxy::Puppet::McPuppet.run hosts
      else
        Proxy::Puppet::Puppetrun.run hosts
      end
    end
  end
end
