#!/usr/bin/perl -w

use strict;
use warnings;
use Time::Piece;
use Data::Dumper;

use constant DEBUG_V => 1;
use constant DEBUG_VV => 0;
use constant DEBUG_VVV => 0;

my $match_criteria = 3;
my $candidate_criteria = 8;
my $user_confirme_criteria = 32;

my $payments = [
    # PID, amounts, date
    [1, 2000, '2010-11-25'],
    [2, 2050, '2012-11-02'],
    [3, 4000, '2011-12-20'],
    [4, 2000, '2012-11-03'],
];

my $invoices = [
    # IID, amounts, date
    [1, 2000, '2010-11-24'],
    [2, 2000, '2012-11-01'],
    [3, 50, '2012-11-01'],
    [4, 2000, '2010-11-24'],
    [5, 2000, '2010-11-24'],

];

sub date_diff {
    my ($a, $b) = @_;
    warn $a if DEBUG_VVV;
    warn $b if DEBUG_VVV;

    my $aa = Time::Piece->strptime($a, "%Y-%m-%d");
    my $bb = Time::Piece->strptime($b, "%Y-%m-%d");

    my $diff = $aa - $bb;
    warn "Returning " . abs(int($diff->days)) if DEBUG_VVV;
    return abs(int($diff->days));
}

# This function generate the hash which key is the amount, and the value is
# array of entry [ID, date].
sub init_structure {
    my $input = shift;
    my $a = {};
    warn Dumper($input) if DEBUG_VVV;
    for (@{$input}) {
 	my ($ID, $amount, $date) = @{$_};
	warn "ID: $ID, amount: $amount, date: $date.\n" if DEBUG_VVV;
	if (defined($a->{$amount})) {
	    # We have seen the same amount before. Add this item to the list.
	    push(@{$a->{$amount}}, [$ID, $date]);
	} else {
	    # This is the first time we see the amount, create a new entry.
	    $a->{$amount} = [[$ID, $date]];
	}

    }

    return $a;
}

# sub bydate {

# }

# The matching function
sub match {
    my $payment_struc = init_structure($payments);
    my $invoices_struc = init_structure($invoices);

    warn Dumper($payment_struc) if DEBUG_VVV;
    warn Dumper($invoices_struc) if DEBUG_VVV;

    # All these 3 return structures are all in the format of
    # { Payment ID # 1 => [ Matched invoice ID #1, ID #2, ... ]
    #   Payment ID # 2 => [ Matched invoice ID #1, ID #2, ... ]
    # }
    my $matched = {};
    my $candidates = {};
    my $user_confirm = {};

    for (keys (%{$payment_struc})) {
	my $amount = $_;
	# print Dumper($payment_struc->{$_});
	if (defined($invoices_struc->{$amount})) {
	    # There is still matching payments in the invoice value.
	    my @payment_arr = @{$payment_struc->{$amount}};
	    my @invoice_arr = @{$invoices_struc->{$amount}};
	    print Dumper(@payment_arr);
	    print Dumper(@invoice_arr);

	    for (@payment_arr) {
		my ($pid, $date) = @{$_};
	    }

	    # my $ddiff = date_diff($payment_struc->{$amount}->[0]->[1], $invoices_struc->{$amount}->[0]->[1]);
	    # print "\n" . $ddiff . "\n";
	}
    }
}

match;
