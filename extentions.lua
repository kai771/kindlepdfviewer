-- List of acceptable extensions

ext = {
	djvuRead = ";djvu;",
	pdfRead  = ";pdf;xps;cbz;",
}


function ext:getReader(ftype)
	local s = ";"
	if ftype == "" then
		return nil
	elseif string.find(self.pdfRead,s..ftype..s) then
		return PDFReader
	elseif string.find(self.djvuRead,s..ftype..s) then
		return DJVUReader
	else
		return nil
	end
end

