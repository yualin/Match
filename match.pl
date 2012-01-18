#!/usr/bin/perl -w

use strict;
use warnings;
use Time::Piece;
use Data::Dumper;

use constant DEBUG_V => 0;
use constant DEBUG_VV => 0;
use constant DEBUG_VVV => 0;

my $match_criteria = 3;
my $candidate_criteria = 8;
my $user_confirm_criteria = 32;

my $payments = [
    # PID, amounts, date
    [1, 2000, '2010-11-25'],
    [2, 2050, '2012-11-02'],
    [3, 4000, '2011-12-20'],
    [4, 2000, '2012-11-03'],
    [5, 2000, '2011-11-17'],
    [6, 2000, '2009-11-17'],
    [7, 3333, '2009-12-17'],
];

my $invoices = [
    # IID, amounts, date
    [1, 2000, '2010-11-24'],
    [2, 2000, '2012-11-01'],
    [3, 50, '2012-11-01'],
    [4, 2000, '2010-11-24'],
    [5, 2000, '2010-11-24'],
    [6, 2000, '2011-11-24'],
    [7, 2000, '2009-12-17'],
    [8, 1111, '2009-11-16'],
    [9, 2222, '2009-11-17'],
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
	    push(@{$a->{$amount}}, [$ID, $date, $amount]);
	} else {
	    # This is the first time we see the amount, create a new entry.
	    $a->{$amount} = [[$ID, $date, $amount]];
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

    # Single Match.
    for my $amount (keys (%{$payment_struc})) {

	warn Dumper($payment_struc->{$_}) if DEBUG_VVV;
	next unless defined($invoices_struc->{$amount});

	# There is still matching payments in the invoice value.
	my $payment_arr = $payment_struc->{$amount};
	my $invoice_arr = $invoices_struc->{$amount};
	warn Dumper($payment_arr) if DEBUG_VVV;
	warn Dumper($invoice_arr) if DEBUG_VVV;

	# Loop through the payment array for this amount
	for my $j (0 .. $#{$payment_arr}) {
	    next unless defined($payment_arr->[$j]);

	    # Debug message
	    warn '$j: ' . $j . "\n" if DEBUG_VV;
	    warn '@payment_arr: ' . "\n" if DEBUG_VV;
	    warn Dumper(@{$payment_arr}) if DEBUG_VV;
	    warn '@payment_arr[' . $j . ']: ' if DEBUG_VV;
	    warn Dumper($payment_arr->[$j]) if DEBUG_VV;
	    my ($pid, $date) = @{$payment_arr->[$j]};
	    warn print $pid . "\n" if DEBUG_VV;
	    warn print $date . "\n" if DEBUG_VV;

	    match_payment_invoice ($invoice_arr, $payment_arr,
				   $j, $pid, $date,
				   0, $match_criteria,
				   $matched);

	    match_payment_invoice ($invoice_arr, $payment_arr,
				   $j, $pid, $date,
				   $match_criteria, $candidate_criteria,
				   $candidates);

	    match_payment_invoice ($invoice_arr, $payment_arr,
				   $j, $pid, $date,
				   $candidate_criteria, $user_confirm_criteria,
				   $user_confirm);
	}
    }

    clean_struct ($payment_struc);
    clean_struct ($invoices_struc);

    # Multiple match.
    my $payments_list = construct_value_list($payment_struc);
    my $invoices_list = construct_value_list($invoices_struc);

    my ($t1, $t2, $t3) = find_matches($payments_list, $invoices_list);

    $matched = {%{$matched}, %{$t1}};
    $candidates = {%{$candidates}, %{$t2}};
    $user_confirm = {%{$user_confirm}, %{$t3}};

    warn 'payment_struc: ' if DEBUG_V;
    warn Dumper($payment_struc) if DEBUG_V;
    warn 'invoices_struc: ' if DEBUG_V;
    warn Dumper($invoices_struc) if DEBUG_V;

    warn '$matched: ' if DEBUG_V;
    warn Dumper($matched) if DEBUG_V;
    warn '$candidates: ' if DEBUG_V;
    warn Dumper($candidates) if DEBUG_V;
    warn '$user_confirm: ' if DEBUG_V;
    warn Dumper($user_confirm) if DEBUG_V;

    return $matched, $candidates, $user_confirm;
}

sub find_matches {
    my $target_list = shift;
    my $elements_list = shift;

    my $matched = {};
    my $candidates = {};
    my $user_confirm = {};

    warn Dumper($target_list) if DEBUG_VV;
    warn Dumper($elements_list) if DEBUG_VV;

    use Math::Combinatorics;

    my $matched_invoice_id_array = [];
    for my $i (2 .. @{$elements_list}) {
	my $combinat =
	    Math::Combinatorics->new(count => $i,
				     data => $elements_list);

	while(scalar (my @a = $combinat->next_combination()) != 0) {

	    my $sum = 0;
	    my $date_array = [];
	    my $invoice_id_array = [];

	    # Get the sum of current combination.
	    for my $e (@a) {
		my ($id, $date, $amount) = @{$e};
		$sum += $amount;
		push @{$date_array}, $date;
		push @{$invoice_id_array}, $id;
	    }

	    next unless invoice_not_used($invoice_id_array,
					 $matched_invoice_id_array);

	    # Check against the target_list
	    for my $e (@{$target_list}) {
		my ($pid, $date, $amount) = @{$e};
		next if $amount != $sum;

		# Check match.

		# 0 - Match, 1 - candidate, 2 - User confirmation, 3 - No.
		my $within_range = 0;
		for (@{$date_array}) {
		    my $diff = abs date_diff($date, $_);

		    if ($diff < $match_criteria) {
			$within_range = 0 if 0 > $within_range;
		    } elsif ($diff < $candidate_criteria) {
			$within_range = 1 if 1 > $within_range;
		    } elsif ($diff < $user_confirm_criteria) {
			$within_range = 2 if 2 > $within_range;
		    } else {
			$within_range = 3;
			last;
		    }
		}

		next if $within_range == 3;

		print "Update found match.\n";
		my $target_hash;
		$target_hash = $matched if $within_range == 0;
		$target_hash = $candidates if $within_range == 1;
		$target_hash = $user_confirm if $within_range == 2;

		$target_hash->{$pid} = $invoice_id_array;
		$matched_invoice_id_array =
		    [
		     @{$matched_invoice_id_array},
		     @{$invoice_id_array},
		    ];
	    }
	}
    }

    return $matched, $candidates, $user_confirm;
}

sub invoice_not_used {
    my $a = shift;
    my $t = shift;

    warn Dumper $a if DEBUG_VVV;
    warn Dumper $t if DEBUG_VVV;
    for my $i (@{$a}) {
	my $r = grep {$_ == $i} @{$t};

	return 0 if $r > 0;
    }

    return 1;
}

sub construct_value_list {
    my $a = shift;

    my $re = [];

    for my $e (keys %{$a}) {
	$re = [@{$re}, @{$a->{$e}}];
    }

    return $re;
}

sub construct_counting_hash {
    my $a = shift;

    my $re = {};

    for my $e (keys %{$a}) {
	$re->{$e} = scalar @{$a->{$e}};
    }

    return $re;
}

# This function is not used.
# sub find_match {
#     my $total_hash = shift;
#     my $elements_hash = shift;

#     print Dumper($total_hash);
#     print Dumper($elements_hash);

#     my $element_count = 0;

#     for my $key (keys %{$elements_hash}) {
# 	$element_count += $elements_hash->{$key};
#     }

#     my $frequencies_array = [];
#     my $data_keys = [keys %{$elements_hash}];

#     for (@{$data_keys}) {
# 	push @{$frequencies_array}, $elements_hash->{$_};
#     }

#     print Dumper($frequencies_array);

#     # use Math::Combinatorics;

#     # for my $i (2 .. $element_count) {
#     # 	my $combinat =
#     # 	    Math::Combinatorics->new(count => $i,
#     # 				     data => $data_keys,
#     # 				     frequency => $frequencies_array);

#     # What the hell does this function want?
#     # 	$a = $combinat->next_multiset;
#     # 	print Dumper($a);
#     # }

# }

sub clean_struct {
    my $hashref = shift;

    for my $amount (keys %{$hashref}) {
	my $src = $hashref->{$amount};
	my $dst = [];

	foreach (@{$src}) {
	    push(@{$dst}, $_) if defined($_);
	}
	warn "dst:\n" if DEBUG_VVV;
	warn Dumper($dst) if DEBUG_VVV;
	if (-1 == $#{$dst}) {
	    delete $hashref->{$amount};
	} else {
	    $hashref->{$amount} = $dst;
	}
    }
}

sub match_payment_invoice {
    my $invoice_arrref = shift;
    my $payment_arrref = shift;
    my $j = shift;
    my $pid = shift;
    my $date = shift;
    my $criteria_min = shift;
    my $criteria_max = shift;
    my $output_hash = shift;

    # Loop through the invoice_arr for candidate_criteria
    for my $i (0 .. $#{$invoice_arrref}) {
	next unless defined($invoice_arrref->[$i]);
	my ($iid, $idate) = @{$invoice_arrref->[$i]};
	my $diff = abs(date_diff($date, $idate));

	# Matching Criteria
	if ($diff >= $criteria_min && $diff < $criteria_max) {
	    $output_hash->{$pid} = [$iid];
	    delete $payment_arrref->[$j];
	    delete $invoice_arrref->[$i];
	    last;
	}
    }
}

match;
