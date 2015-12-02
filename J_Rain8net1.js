// Device Service
var R8N_SID = "urn:wgldesigns-com:serviceId:Rain8Net1";
var timerRunning = false;

//local ip
ipaddress = data_request_url;

function layout()
{
  var html = "";
  html += '<!DOCTYPE html>';
  html += '<head>';
  html += '<style type="text/css">';
  html += 'div#divContainer';
  html += '{';
  html += 'max-width: 800px;';
  html += 'margin: 0 auto;';
  html += 'font-family: Calibri;';
  html += 'font-size:1em;';
  html += 'padding: 0.1em 0.1em 0.1em 0.1em;';
  html += 'background-color: #00CCEE;';
  html += '}';
  
  //* header *//
  html += 'h1 {color:#FFE47A; font-size:1.5em;text-align:center;}';
  //* table *//
  html += 'table.formatLogPanel {';
  html += 'width: 100%;';
  html += 'border-collapse:collapse;';
  html += 'color: #606060;';
  html += '}';
  //* table's thead section, head row style *//
  html += 'table.formatLogPanel thead tr td';
  html += '{';
  html += 'background-color: White;';
  html += '}';
  //* table's thead section, coulmns header style *//
  html += 'table.formatLogPanel thead tr th';
  html += '{';
  html += 'vertical-align:middle;';
  html += 'text-align:center;';
  html += 'background-color: #808080;';
  html += 'color: #dadada;';
  html += '}';
  //* table's tbody section, odd rows style *//
  html += 'table.formatLogPanel tbody tr:nth-child(odd) {';
  html += 'background-color: #fafafa;';
  html += '}';
  //* table's tbody section, even rows style *//
  html += 'table.formatLogPanel tbody tr:nth-child(even) {';
  html += 'background-color: #efefef;';
  html += '}';
  //* table's tbody section, last row style *//
  html += 'table.formatLogPanel tbody tr:last-child {';
  html += 'border-bottom: solid 1px #404040;';
  html += '}';
  //* table's tbody section, separator row pseudo-class *//
  html += 'table.formatLogPanel tbody tr.separator {';
  html += 'background-color: #808080;';
  html += 'background: -webkit-gradient(linear, left top, left bottom, from(#025CB6), to(#909090));';
  html += 'background: -moz-linear-gradient(top, #025CB6, #909090);';
  html += 'color: #dadada;';
  html += '}';
  //* table's td element, all section *//
  html += 'table.formatLogPanel td {';
  html += 'vertical-align:middle;';
  //html += 'padding: 0.5em;';
  html += '}';
  //* table's tfoot section *//
  html += 'table.formatLogPanel tfoot{';
  html += 'text-align:center;';
  html += 'color:#303030;';
  html += 'text-shadow: 0 1px 1px rgba(255,255,255,0.3);';
  html += '}';
  //* input *//
  html += 'input';
  html += '{';
  html += 'width: 25px;';
  html += 'height:10px;';
  html += 'font-family: Calibri;';
  html += 'font-size: 0.95em;';
  html += 'vertical-align:middle;';
  html += 'text-align: center;';
  html += '}';
  html += 'input.btn1';
  html += '{';
  html += 'width: 25px;';
  html += 'height:15px;';
  html += '} ';
  html += 'label';
  html += '{';
  html += 'font-family: Calibri;';
  html += 'vertical-align:middle;';
  html += 'float:left;';
  html += '} ';
  //******//
  html += '</style>';
  html += '</head>';
  html += '<body>';
  return html;
}

/**********
 * Event Log tab
 **********/
function timers(device)
{
  var html = layout();
  var LogStart;
  //<!-- CENTTERED COLUMN ON THE PAGE-->/
  html += '<div id="divContainer">';
  html += '<h1>RAIN8NET TIMERS</h1>';
  //<!-- HTML5 TABLE FORMATTED VIA CSS3-->
  html += '<table class="formatLogPanel" id="logTableTop" >';
  //<!-- TABLE HEADER-->
  html += '<thead>';
  //html += '<tr><td colspan=5>+ + + Disclaimer + + +</td></tr>';
  html += '<tr>';
  html += '<th>DEVICE</th><th>ZONE</th><th>MASTER</th><th>PROG</th><th>LAST RUN</th>';
  html += '</tr>';
  html += '</thead>';
  html += '<tbody id="logTable" >';
  html += '</tbody>';
  //<!-- TABLE FOOTER-->
  html += '<tfoot>';
  html += '<tr><td colspan=5 id="status"></td></tr>';
  html += '</tfoot>';
  html += '</table>';
  html += '</div>';
  html += '</body>';
  html += '</html>';
  set_panel_html(html);
  getTimers($('logTable'), device, $('status'));
}

function getTimers(table, device, status)
{
  status.innerHTML = '<td colspan="5">...Getting response...</td>';
  new Ajax.Request("../port_3480/data_request",
  {
    method: "get",
    parameters:
    {
      id: "lr_programs",
      rand: Math.random(),
      output_format: "json"
    },
    onSuccess: function (response)
    {
      status.innerHTML = '<td colspan="5">...Response received...</td>';
      var Log = response.responseText.evalJSON();
      var row = table.insertRow(-1);
      for (var i = 0; i < Log.length; i++)
      {
        var dt = new Date((Log[i].LastRun)*1000);
        
        html = '';
        var formP1 = '<form name ="' + Log[i].Device + '">'
        var formP2 = '<input type="text" name="proga" value ="' + Log[i].ProgramA + '"/>';
        var formP3 = '<input type="text" name="progb" value ="' + Log[i].ProgramB + '"/>';
        var formP4 = '<input type= "button" value= "Set" class="btn1" onclick="setTimer(' + device + ',' + Log[i].Device + ')"/></form>';
        var form = formP1 + formP2 + formP3 + formP4
        row = table.insertRow(i);
        var dev = row.insertCell(0);
        var zone = row.insertCell(1);
        var master = row.insertCell(2);
        var prog = row.insertCell(3);
        var lastRun = row.insertCell(4);
        dev.innerHTML = Log[i].Device;
        zone.innerHTML = Log[i].Zone;
        master.innerHTML = Log[i].Master;
        prog.innerHTML = form;
        lastRun.innerHTML = dt.toDateString();
      }

      status.innerHTML = '<td colspan="5">Completed</td>';
    },
    onFailure: function ()
    {
      status.innerHTML = '<td colspan="4">...Failed to get timers...</td>';
    }

  });

}


function setTimer(device, zone)
{  
  var proga = document.forms.namedItem(zone).elements[0].value;
  var progb = document.forms.namedItem(zone).elements[1].value;
  new Ajax.Request("../port_3480/data_request",
  {
    method: "get",
    parameters:
    {
      id: "lu_action",
      serviceId: R8N_SID,
      action: "SetTimers",
      DeviceNum: device,
      Zone: zone,
      ProgramA: proga,
      ProgramB: progb,
      output_format: "json"
    },
    onSuccess: function (response)
    {
      var custom = response.responseText.evalJSON();
    },
    onFailure: function () {}
  });
}
