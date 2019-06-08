#!/usr/bin/env perl

main();

sub main {
	setDirectory();
	my @files = scrapeDirectory();
	print "@files\n";
}


sub scrapeDirectory {
	my @allFiles = <*>;

	my @watchedFiles;
	for my $file (@allFiles) {
		if ($file =~ /^[^\.]{1}.*$/) {
			push(@watchedFiles, $file);
		}
	}

	return @watchedFiles;
}

sub setDirectory {
	my $cdDir = $ARGV[0];
	if ($cdDir eq "") {
		die "No directory to change to.\n";
	}
	# print "changing to $ARGV[0]\n";
	chdir("$ARGV[0]");
}