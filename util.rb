# Returns the number of processor for Linux, OS X or Windows.
def number_of_processors
  if RUBY_PLATFORM =~ /linux/
    return `cat /proc/cpuinfo | grep processor | wc -l`.to_i
  elsif RUBY_PLATFORM =~ /darwin/
    return `sysctl -n hw.logicalcpu`.to_i
  elsif RUBY_PLATFORM =~ /win32/ or RUBY_PLATFORM =~ /mingw32/
    # this works for windows 2000 or greater
    require 'win32ole'
    wmi = WIN32OLE.connect('winmgmts://')
    wmi.ExecQuery('select * from Win32_ComputerSystem').each do |system|
      begin
        processors = system.NumberOfLogicalProcessors
      rescue
        processors = 0
      end
      return [system.NumberOfProcessors, processors].max
    end
  end
  raise "can't determine 'number_of_processors' for '#{RUBY_PLATFORM}'"
end
