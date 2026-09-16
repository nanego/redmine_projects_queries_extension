Deface::Override.new :virtual_path  => 'projects/_list',
                     :name          => 'add-quick-search-textfield',
                     :insert_before => ".autoscroll",
                     :text          => <<SCRIPT
<input type=text name=filter-by-tracker id=filter-by-tracker class=filter placeholder='<%= l('quick_search') %>' >
SCRIPT

Deface::Override.new :virtual_path  => 'projects/_list',
                     :name          => 'add-activity-graphs',
                     :insert_after  => "#csv-export-options",
                     :partial       => 'projects/activity_graphs'
