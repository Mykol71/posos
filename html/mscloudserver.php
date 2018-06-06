<?php
if ($_GET['run']) {
  # This code will run if ?run=true is set.
  shell_exec("cd /home/mgreen/mscloudserver");
  shell_exec("./MENU");
  shell_exec("cd -");
}
?>

<!-- This link will add ?run=true to your URL, myfilename.php?run=true -->
<a href="?run=true">Install Dependencies</a>
