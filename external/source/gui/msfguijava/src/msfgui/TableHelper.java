package msfgui;

import java.awt.Component;
import java.util.Vector;
import javax.swing.JTable;
import javax.swing.table.*;

/**
 *
 * @author scriptjunkie
 */
public class TableHelper {

	/** Sets preferred column widths for the table based on header and data content. */
	public static void fitColumnWidths(TableModel model, JTable mainTable) {
		for (int col = 0; col < model.getColumnCount();col++) {
			TableColumn tc = mainTable.getColumnModel().getColumn(col);
			TableCellRenderer tcr = mainTable.getDefaultRenderer(model.getColumnClass(col));
			int width = tcr.getTableCellRendererComponent(mainTable,
					model.getColumnName(col), false, false, 0, col).getPreferredSize().width;
			for (int row = 0; row < model.getRowCount();row++) {
				Component c = tcr.getTableCellRendererComponent(mainTable,
						model.getValueAt(row, col), false, false, row, col);
				if (width < c.getPreferredSize().width)
					width = c.getPreferredSize().width;
			}
			tc.setPreferredWidth(width);
		}
	}

	/** Based on a header row demonstrating the length and position of the fields,
	 * break a line into column elements. */
	protected static Vector fill(String line, String headerRow){
		Vector output = new Vector();
		boolean lastWhitespace = false;
		StringBuilder val = new StringBuilder();
		int max = Math.max(headerRow.length(), line.length());
		for(int i = 0; i < max; i++){
			if(headerRow.length() <= i){
				val.append(line.charAt(i));
				continue;
			}
			if(lastWhitespace && !Character.isWhitespace(headerRow.charAt(i))){
				output.add(val.toString().trim());
				val.delete(0, val.length());
			}
			if(line.length() > i)
				val.append(line.charAt(i));
			lastWhitespace = Character.isWhitespace(headerRow.charAt(i));
		}
		output.add(val.toString().trim());
		return output;
	}
}
