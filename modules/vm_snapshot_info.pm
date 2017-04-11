sub vm_snapshot_info
    {
    my ($vmname) = @_;
    my $output = " ";
    my $actual_state;            # Hold the actual state for to be compared
    my $true_sub_sel=1;          # Just a flag. To have only one return at the en
                                 # we must ensure that we had a valid subselect. If
                                 # no subselect is given we select all
                                 # 0 -> existing subselect
                                 # 1 -> non existing subselect
 my $vms = Vim::find_entity_views(
     view_type => 'VirtualMachine',
    filter => {'name' => $vmname}
 );

    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       }


    if (defined($subselect) and $subselect eq "snapshot") {
       $subselect = "all";
       $true_sub_sel = 0;
    }


foreach my $vm_view ( @{$vms} ) {
    my $vm_name     = $vm_view->{summary}->{config}->{name};
    if ($vm_name ne $vmname) {
        next; 
    }
    
    my $vm_snapinfo = $vm_view->{snapshot};
    return  check_snapshot_age( $vm_name, $vm_snapinfo->{rootSnapshotList} );
}

return (3, "Unknown VM, $vmname does not exists");

sub check_snapshot_age {
    my $vm_name     = shift;
    my $vm_snaplist = shift;
    my $count = 0;

   if (defined($isregexp))
      {
      $isregexp = 1;
      }
   else
      {
      $isregexp = 0;
      }


    foreach my $vm_snap ( @{$vm_snaplist} ) {
        if ( $vm_snap->{childSnapshotList} ) {
            return check_snapshot_age( $vm_name, $vm_snap->{childSnapshotList} );
        }
        
        my $epoch_snap = str2time( $vm_snap->{createTime} );
        my $days_snap  = sprintf("%0.1f", ( time() - $epoch_snap ) / 86400 );
        my $actual_state = check_against_threshold($days_snap);

       if (defined($blacklist))
       {
         if (isblacklisted(\$blacklist, $isregexp,$vm_snap->{name}))
         {
            next;
         }
       }

       if (defined($whitelist))
       {
         if (isnotwhitelisted(\$whitelist, $isregexp, $vm_snap->{name}))
         {
             $actual_state = check_against_threshold($days_snap);
         }
         else {
             $actual_state = 0;

         }
       }

        return(
            $actual_state,
            sprintf(
                "Snapshot \"%s\" (VM: '%s') is %d days old",
                $vm_snap->{name}, $vm_name, $days_snap
            )
        );
    }

    if ($count == 0) {
        return (0, 'No snapshots found');
    }

}

if ($true_sub_sel == 1)
   {
   get_me_out("Unknown VM RUNTIME subselect");
   }
else
   {
   return ($state, $output);
   }
}

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
