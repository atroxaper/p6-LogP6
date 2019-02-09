unit module Custom;

use LogP6 :configure;
use LogP6::Writer;
use LogP6::Helpers::LoggerWrapperSyncTime;

sub handle1(:$file-name) is export {
say 'custom handle1 ', $file-name;
	$file-name.IO.open(:create, :append);
}

sub writer1(:$name) is export {
say 'custom writer1 ', $name;
	LogP6::WriterConfStd.new(:$name);
}

sub before-check1() is export {
	my sub before($context) { True; }
	return &before;
}

sub wrapper(Int() :$seconds) is export {
	return LogP6::Helpers::LoggerWrapperFactorySyncTime
			.new(:$seconds, :&get-logger-pure);
}