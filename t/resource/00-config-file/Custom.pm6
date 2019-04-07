unit module Custom;

use LogP6::WriterConf::Std;
use LogP6::FilterConf::Std;
use LogP6::Wrapper::SyncTime;
use IOString;

my %strings = %();

sub io-string(:$name) is export {
	%strings{$name} //= IOString.new;
}

sub handle1(:$file-name) is export {
	$file-name.IO.open(:create, :append);
}

sub writer(:$name) is export {
	LogP6::WriterConf::Std.new(:$name);
}

sub filter(:$name) is export {
	LogP6::FilterConf::Std.new(:$name);
}

sub before-check1() is export {
	return &before1;
}

sub before-check2() is export {
	return &before2;
}

sub after-check() is export {
	return &after;
}

sub wrapper(Int() :$seconds) is export {
	return LogP6::Wrapper::SyncTime::Wrapper.new(:$seconds);
}

sub before1($context) {
	True;
}

sub before2($context) {
	True;
}

sub after($context) {
	True;
}