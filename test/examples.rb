#
#
# load "dlog.rb"

#
#
dlog 1

#
#
rlog.warn "2"

#
#
benchmark do Thread.send(:sleep, 0.015); 1 end
benchmark "a message" do Thread.send(:sleep, 0.01); 1 end
benchmark.info "a message" do Thread.send(:sleep, 0.02); 1 end


benchmark "raise" do Thread.send(:sleep, 0.02); raise "1" end rescue nil
benchmark.warn "raise" do Thread.send(:sleep, 0.02); raise "1" end rescue nil
