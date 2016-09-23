###################### Author: Francisco Jurman
###################### Email: fjurman@hotmail.com
###################### Version 3
######################

$debug = false
$firmware_nameXM = "XM.v5.6.4.28924.160331.1253.bin"
$firmware_versionXM = "5.6.4"
$firmware_nameXW = "XW.v5.6.4.28924.160331.1238.bin"
$firmware_versionXW = "5.6.4"
$panel_user = 'admin'
$port = 8822
$subs = []
ip = ARGV[0] ? ARGV[0] : '192.168.1.20'

require 'rubygems'
require 'highline/import'
require 'net/ssh'
require 'net/ssh/session'
require 'net/ssh/shell'
require 'net/scp'
require 'timeout'
require 'json'

#################################################################
# Completa el array $subs con el ip de cada CPE dentro del Panel
#################################################################
def fill(ip)
  sessionP = Net::SSH::Session.new(ip, $panel_user, $panel_pass, :port => $port)
  sessionP.open
    $subs = JSON.parse(sessionP.capture('wstalist')).each.inject([]){ |a,d| a << d["lastip"] }
  sessionP.close
end # End NetSSH
#################################################################
# Corre check_firmware para CADA CPE en el array $subs
#################################################################
def run(ip)
  time = Time.now
  puts yellow("Usuario por defecto de panel: #{$panel_user}")
  $panel_pass = ask("Ingresar contraseña del panel: ") {|q| q.echo = false }
  puts green("---------")
  $cliente_user = ask("Ingresar usuario de CPE: ") {|c| c.echo = true}
  puts green("Usuario CPE ingresado: #{$cliente_user}")
  $cliente_pass = ask("Ingresar contraseña de CPE: ") {|r| r.echo = false}
  puts yellow("---------")
  puts "Inicio > " + time.inspect 
  puts "----------------------------"
  fill(ip)
  $subs.each{ |ip| check_firmware(ip) }
  time2 = Time.now
  puts "Fin > " + time2.inspect
  puts "----------------------------"
end
#################################################################
#
#################################################################
  def ping(ip)
    system("ping -c 5 -s 1000 #{ip} > ping")
  end
#################################################################
#
#################################################################
  def up?(ip)
    ping ip
  end
#################################################################
#
#################################################################
def wait(ip)
    until up?(ip)
      sleep 1
      print "."
    end
    puts
  end
#################################################################
# Conecta por SSH al CPE y trae datos
#################################################################
def check_firmware(ip)
  begin
    sessionC = Net::SSH::Session.new(ip, $cliente_user, $cliente_pass, :port => $port)
    sessionC.open       
    $version = sessionC.capture('cat /usr/lib/version').chomp
    $name = sessionC.capture('cat /tmp/system.cfg | grep resolv.host.1.name=').strip
    $name.sub!("resolv.host.1.name=","")

    if $version.include? "XM."
          puts red("XM")
          puts "Nombre: #{$name}\n"
          puts "IP: #{ip}\n"
          puts "Version: #{$version}\n"
        unless $version.include? $firmware_versionXM
                puts yellow("Empieza a subirse el firmware")
                sleep until update_firmwareXM(ip)
                puts red("------ Preparándose para ejecutar la actualización. Este proceso demora aprox. 1.30min ------")
                puts "###########################################################################################"
                
                begin
                  Timeout::timeout(90){ sessionC.run('/sbin/ubntbox fwupdate.real -m /tmp/firmware') }
                rescue
                  # puts "[ ] Restarting the script now"
                  sleep 5
                  check_firmware(ip)
                end

                wait(ip)
          end #unless

    elsif $version.include? "XW."
    
          puts red("XW")
          puts "Nombre: #{$name}\n"
          puts "IP: #{ip}\n"
          puts "Version: #{$version}\n"
        unless $version.include? $firmware_versionXW
                puts yellow("Empieza a subirse el firmware")
                sleep until update_firmwareXW(ip)
                puts red("------ Preparándose para ejecutar la actualización. Este proceso demora aprox. 1.30min ------")
                puts "###########################################################################################"
                
                begin
                  Timeout::timeout(90){ sessionC.run('/sbin/ubntbox fwupdate.real -m /tmp/firmware') }
                rescue
                  # puts "[ ] Restarting the script now"
                  sleep 5
                  check_firmware(ip)
                end

                wait(ip)
          end #unless
    else

          puts "XS"

    end  
  sessionC.close
  rescue Exception => e
      puts e
  end #begin
end #END check firmware
#################################################################
#
#################################################################

def update_firmwareXM(ip)
      Net::SSH.start(ip, $cliente_user, {:password => $cliente_pass,:port => $port}) do |ssh|
          ssh.scp.upload! $firmware_nameXM, "/tmp/firmware"
          puts green("------ Firmware Uploaded -----")
      return true
      end
end

def update_firmwareXW(ip)
      Net::SSH.start(ip, $cliente_user, {:password => $cliente_pass,:port => $port}) do |ssh|
          ssh.scp.upload! $firmware_nameXW, "/tmp/firmware"
          puts green("------ Firmware Uploaded -----")
      return true
      end
end
def colorize(text, color_code)
  "\e[#{color_code}m#{text}\e[0m"
end

def red(text); colorize(text, 31); end
def green(text); colorize(text, 32); end
def yellow(text); colorize(text, 33); end

run(ip)
