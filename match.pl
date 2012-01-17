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
    [5, 2000, '2011-11-17'],
];

my $invoices = [
    # IID, amounts, date
    [1, 2000, '2010-11-24'],
    [2, 2000, '2012-11-01'],
    [3, 50, '2012-11-01'],
    [4, 2000, '2010-11-24'],
    [5, 2000, '2010-11-24'],
    [6, 2000, '2011-11-24'],
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

    # Loop through the payment sturcture.
    for (keys (%{$payment_struc})) {
	my $amount = $_;

	warn Dumper($payment_struc->{$_}) if DEBUG_VVV;
	next unless defined($invoices_struc->{$amount});

	# There is still matching payments in the invoice value.
	my @payment_arr = @{$payment_struc->{$amount}};
	my @invoice_arr = @{$invoices_struc->{$amount}};
	warn Dumper(@payment_arr) if DEBUG_VVV;
	warn Dumper(@invoice_arr) if DEBUG_VVV;

	# Loop through the payment array for this amount
	for my $j (0 .. $#payment_arr) {
	    next unless defined($payment_arr[$j]);

	    # Debug message
	    warn '$j: ' . $j . "\n" if DEBUG_VV;
	    warn '@payment_arr: ' . "\n" if DEBUG_VV;
	    warn Dumper(@payment_arr) if DEBUG_VV;
	    warn '@payment_arr[' . $j . ']: ' if DEBUG_VV;
	    warn Dumper($payment_arr[$j]) if DEBUG_VV;
	    my ($pid, $date) = @{$payment_arr[$j]};
	    warn print $pid . "\n" if DEBUG_VV;
	    warn print $date . "\n" if DEBUG_VV;

	    # Flag, match found for this payment.
	    my $matched_flag = 0;

	    # Loop through the invoice_arr
	    for my $i (0 .. $#invoice_arr) {
		next unless defined($invoice_arr[$i]);
		my ($iid, $idate) = @{$invoice_arr[$i]};
		my $diff = abs(date_diff($date, $idate));

		# Matching Criteria,
		if ($diff < $match_criteria) {
		    $matched->{$pid} = [($iid)];
		    $matched_flag = 1;
		} elsif ($diff < $candidate_criteria) {
		    $candidates->{$pid} = [($iid)];
		    $matched_flag = 1;
		} elsif ($diff < $user_confirme_criteria) {
		    $candidates->{$pid} = [($iid)];
		    $matched_flag = 1;
		}

		# Process on the payment_arr and invoice_arr
		if ($matched_flag == 1) {
		    delete $payment_arr[$j];
		    delete $invoice_arr[$i];
		    last;
		} else {
		}
	    }
	    if ($matched_flag == 1) {
		next;
	    }

	    # my $ddiff = date_diff($payment_struc->{$amount}->[0]->[1], $invoices_struc->{$amount}->[0]->[1]);
	    # print "\n" . $ddiff . "\n";
	}
    }
    warn '$matched: ' if DEBUG_V;
    warn Dumper($matched) if DEBUG_V;
    warn '$candidates: ' if DEBUG_V;
    warn Dumper($candidates) if DEBUG_V;
    warn '$user_confirm: ' if DEBUG_V;
    warn Dumper($user_confirm) if DEBUG_V;
}

match;
