$(document).ready(function () {
  initHistoryEvents();
	
	initPaginationButtons();
	
	initFragmentChange();
});


/**************************/
/*    SEARCH HISTORY      */
/**************************/


function initHistoryEvents() {
	$("#search_form .submit_button").live("click", function(){
    setSearchHistory();
    return false;
  });

	$('#search_form #search_terms').live("keypress", function(event) {
    if (event && event.keyCode == 13) { /* check if enter was pressed */
      setSearchHistory();
      return false;
    }
  });

  $("a.ajax_sort").live("click", function() {
    var sort = $(this).attr('value');
		$(':input[id=sort]').val(sort);
		setSearchHistory();
    return false;
  });

  $("a.ajax_no_sort").live("click", function() {
		$(':input[id=sort]').val('');
		setSearchHistory();
    return false;
  });
}



function setSearchHistory() {
  var search_terms = $("#search_terms").val();
  if (search_terms.length > 0) {
		
    search_terms = search_terms.trim();
  }
  if ($(':input[id=sort]').length > 0) {
    var sort = $(':input[id=sort]').val();
	  $.setFragment({ "search_terms": search_terms, "sort" : sort, "page": "1"});
  } else {
    $.setFragment({ "search_terms": search_terms, "page": "1"});
  }
}

/**********************/
/*    PAGINATION      */
/**********************/

function initPaginationButtons() {
	$(".pagination a").live("click", function() {
    $.setFragment({ "page" : $.queryString(this.href).page })
    return false;
  });
}


function initFragmentChange() {
  $(document).bind("fragmentChange.page", function() {
		if ($.fragment().page) {
			$.getScript($.queryString(document.location.href, { 
				"page": $.fragment().page,
				"sort": $.fragment().sort,
				"search_terms": $.fragment().search_terms
			}));
		}
  });

  if ($.fragment().page) {
    $(document).trigger("fragmentChange.page");
  }
}
